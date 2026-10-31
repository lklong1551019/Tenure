import { describe, expect, it, vi } from 'vitest'
import { MutableClock, sampleBoard, sampleEntry } from '../../test/fakes'
import { LedgerError } from './errors'
import { LedgerStore } from './ledgerStore'
import { isDeleted } from './model'

const setup = () => {
  const clock = new MutableClock()
  return { clock, store: new LedgerStore(undefined, clock) }
}

describe('LedgerStore', () => {
  it('stamps a save with now and clears a delete', () => {
    const { clock, store } = setup()
    const saved = store.saveBoard({ ...sampleBoard(), deletedAt: 5 })
    expect(saved.updatedAt).toBe(clock.now())
    expect(isDeleted(saved)).toBe(false)
    expect(store.snapshot().boards).toEqual([saved])
  })

  it('always moves the stamp forward, even when the clock runs behind', () => {
    const { clock, store } = setup()
    const board = store.saveBoard(sampleBoard())
    clock.set(clock.now() - 60_000)
    const edited = store.saveBoard({ ...board, name: 'renamed' })
    expect(edited.updatedAt).toBe(board.updatedAt + 1)
  })

  it('tombstones a board and every entry on it', () => {
    const { clock, store } = setup()
    const board = store.saveBoard(sampleBoard())
    const other = store.saveBoard(sampleBoard('Other'))
    store.saveEntry(sampleEntry('one', board))
    store.saveEntry(sampleEntry('kept', other))
    clock.advance()
    store.deleteBoard(board.id)
    const { boards, entries } = store.snapshot()
    expect(boards.find((b) => b.id === board.id)?.deletedAt).toBe(clock.now())
    expect(entries.filter(isDeleted).map((e) => e.name)).toEqual(['one'])
    expect(entries.find((e) => e.name === 'kept')?.deletedAt).toBeUndefined()
  })

  it('needs a live board for an entry', () => {
    const { store } = setup()
    const board = store.saveBoard(sampleBoard())
    store.deleteBoard(board.id)
    const before = store.snapshot()
    expect(() => store.saveEntry(sampleEntry('x', board))).toThrow(LedgerError)
    expect(store.snapshot()).toBe(before)
  })

  it('reports whether a merge changed anything', () => {
    const { store } = setup()
    const board = store.saveBoard(sampleBoard())
    expect(store.merge(store.snapshot())).toBe(false)
    expect(store.merge({ boards: [], entries: [sampleEntry('new', board)] })).toBe(true)
    expect(store.snapshot().entries.map((e) => e.name)).toEqual(['new'])
  })

  it('tells subscribers about every change', () => {
    const { store } = setup()
    const listener = vi.fn()
    const unsubscribe = store.subscribe(listener)
    const board = store.saveBoard(sampleBoard())
    store.saveEntry(sampleEntry('x', board))
    unsubscribe()
    store.deleteBoard(board.id)
    expect(listener).toHaveBeenCalledTimes(2)
  })
})
