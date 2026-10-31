import { beforeEach, describe, expect, it } from 'vitest'
import { fixtureText } from '../../../test/fixtures'
import { FakeRemoteStore, MutableClock, sampleBoard, sampleEntry } from '../../../test/fakes'
import { ledgerFileCodec as codec } from '../../data/ledgerFileCodec'
import { SyncError, type SyncErrorKind } from '../errors'
import { LedgerStore } from '../ledgerStore'
import { liveEntries } from '../model'
import { addDays } from '../timestamp'
import { SyncLedger } from './syncLedger'

let clock: MutableClock
let remote: FakeRemoteStore

/** One device: its own store and its own sync record, sharing the remote. */
const device = () => {
  const store = new LedgerStore(undefined, clock)
  const sync = new SyncLedger(remote, codec, clock)
  return { store, sync, run: () => sync.run(store) }
}

const names = (store: LedgerStore) =>
  liveEntries(store.snapshot())
    .map((entry) => entry.name)
    .sort()

const failure = async (promise: Promise<unknown>): Promise<SyncErrorKind> => {
  try {
    await promise
  } catch (error) {
    if (error instanceof SyncError) return error.reason
    throw error
  }
  throw new Error('expected a SyncError')
}

/** The Mac's first sync: the file exists before the web ever runs. */
const seed = () => {
  const mac = device()
  const board = mac.store.saveBoard(sampleBoard())
  remote.put(codec.encode(mac.store.snapshot()))
  return { mac, board }
}

beforeEach(() => {
  clock = new MutableClock()
  remote = new FakeRemoteStore()
})

describe('SyncLedger', () => {
  it('never creates the remote file', async () => {
    const web = device()
    web.store.saveBoard(sampleBoard())
    expect(await failure(web.run())).toEqual({ kind: 'noRemoteFile' })
    expect(remote.uploadCount).toBe(0)
  })

  it('pulls the existing file, then has nothing to do', async () => {
    seed()
    const web = device()
    expect(await web.run()).toBe('pulled')
    expect(await web.run()).toBe('upToDate')
    expect(remote.uploadCount).toBe(1)
  })

  it('reads a file the Mac wrote and writes it back unchanged when nothing changed', async () => {
    remote.put(fixtureText('file-full.json'))
    const web = device()
    clock.set(1_780_000_100_000)
    expect(await web.run()).toBe('pulled')
    expect(codec.encode(web.store.snapshot())).toBe(fixtureText('file-full.json'))
    expect(remote.uploadCount).toBe(1)
  })

  it('converges two devices', async () => {
    const { board } = seed()
    const one = device()
    const two = device()
    await one.run()
    await two.run()
    clock.advance()
    one.store.saveEntry(sampleEntry('from one', board))
    clock.advance()
    two.store.saveEntry(sampleEntry('from two', board))
    expect(await one.run()).toBe('pushed')
    expect(await two.run()).toBe('pushed')
    expect(await one.run()).toBe('pulled')
    expect(names(one.store)).toEqual(['from one', 'from two'])
    expect(names(two.store)).toEqual(['from one', 'from two'])
  })

  it('carries a delete to the other device', async () => {
    const { board } = seed()
    const one = device()
    await one.run()
    const entry = one.store.saveEntry(sampleEntry('gone', board))
    await one.run()
    const two = device()
    await two.run()
    clock.advance()
    two.store.deleteEntry(entry.id)
    await two.run()
    await one.run()
    expect(names(one.store)).toEqual([])
  })

  it('merges an upload that landed between download and upload, then uploads again', async () => {
    const { board } = seed()
    const one = device()
    const two = device()
    await one.run()
    await two.run()
    clock.advance()
    two.store.saveEntry(sampleEntry('sneaky', board))
    clock.advance()
    one.store.saveEntry(sampleEntry('mine', board))
    remote.interleave(async () => {
      await two.run()
    })
    expect(await one.run()).toBe('pushed')
    expect(names(one.store)).toEqual(['mine', 'sneaky'])
    const head = codec.decode(remote.headData!)
    expect(head.entries.map((entry) => entry.name).sort()).toEqual(['mine', 'sneaky'])
  })

  it('refuses a corrupt, newer, or future-stamped remote and changes nothing', async () => {
    const { board } = seed()
    const web = device()
    await web.run()
    const before = web.store.snapshot()

    remote.put('garbage')
    expect(await failure(web.run())).toEqual({ kind: 'corruptRemote' })

    remote.put('{"format": "tenure", "version": 2, "boards": [], "entries": []}')
    expect(await failure(web.run())).toEqual({ kind: 'unsupportedRemote', version: 2 })

    const future = { ...board, name: 'future', updatedAt: addDays(clock.now(), 2) }
    remote.put(codec.encode({ boards: [future], entries: [] }))
    expect(await failure(web.run())).toEqual({ kind: 'corruptRemote' })

    expect(web.store.snapshot()).toBe(before)
  })

  it('maps transport errors', async () => {
    seed()
    const web = device()
    remote.failNext({ kind: 'offline' })
    expect(await failure(web.run())).toEqual({ kind: 'remote', error: { kind: 'offline' } })
  })

  it('gives up as busy when another device uploads during every attempt', async () => {
    const { board } = seed()
    const web = device()
    await web.run()
    const other = device()
    await other.run()
    web.store.saveEntry(sampleEntry('mine', board))
    let count = 0
    const keepUploading = async () => {
      clock.advance()
      other.store.saveEntry(sampleEntry(`other ${count++}`, board))
      remote.put(codec.encode(other.store.snapshot()))
      remote.interleave(keepUploading)
    }
    remote.interleave(keepUploading)
    expect(await failure(web.run())).toEqual({ kind: 'busy' })
  })
})
