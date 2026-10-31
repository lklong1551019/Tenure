// `npm run dev`, then open /Tenure/app/?demo: the app on sample data, with no Google account
// and no network. Development only: `import.meta.env.DEV` is false in a build, so none of
// this reaches the published page.
import { dayDate, yearMonth } from '../domain/calendar'
import { LedgerStore } from '../domain/ledgerStore'
import type { Board, Entry, LedgerSnapshot } from '../domain/model'
import type { RemoteRevision, RemoteStorePort } from '../domain/ports'
import { SyncLedger } from '../domain/sync/syncLedger'
import type { AuthState } from '../data/googleAuth'
import { ledgerFileCodec } from '../data/ledgerFileCodec'
import { AppModel, type AuthPort } from './appModel'

class DemoAuth implements AuthPort {
  private current: AuthState = { kind: 'signedOut' }
  private readonly listeners = new Set<() => void>()
  state = () => this.current
  subscribe = (listener: () => void) => {
    this.listeners.add(listener)
    return () => this.listeners.delete(listener)
  }
  load = async () => {}
  signIn = async () => this.set({ kind: 'signedIn' })
  signOut = () => this.set({ kind: 'signedOut' })
  private set(state: AuthState) {
    this.current = state
    for (const listener of this.listeners) listener()
  }
}

/** Drive's revision history, in memory. */
class DemoRemote implements RemoteStorePort {
  private readonly revisions: string[] = []
  constructor(initial: LedgerSnapshot) {
    this.revisions.push(ledgerFileCodec.encode(initial))
  }
  head = async () => `r${this.revisions.length}`
  download = async (revision: RemoteRevision) =>
    new TextEncoder().encode(this.revisions[Number(revision.slice(1)) - 1] ?? '')
  upload = async (data: string) => {
    this.revisions.push(data)
    return `r${this.revisions.length}`
  }
  revisionsAfter = async (revision: RemoteRevision) =>
    this.revisions
      .slice(Number(revision.slice(1)))
      .map((_, index) => `r${Number(revision.slice(1)) + index + 1}`)
}

const stamp = Date.UTC(2026, 9, 1)
const board = (
  id: string,
  name: string,
  start: [number, number],
  end?: [number, number],
): Board => ({
  id,
  name,
  start: yearMonth(...start),
  ...(end && { end: yearMonth(...end) }),
  createdAt: stamp,
  updatedAt: stamp,
})
const entry = (id: string, boardId: string, fields: Partial<Entry>): Entry => ({
  id,
  boardId,
  name: '',
  type: 'dev',
  date: dayDate(2026, 1, 1),
  tags: [],
  problem: '',
  why: '',
  solution: '',
  impact: '',
  difficulties: '',
  metrics: [],
  createdAt: stamp,
  updatedAt: stamp,
  ...fields,
})

const current = '00000000-0000-4000-8000-0000000000B2'
const former = '00000000-0000-4000-8000-0000000000B1'

const sample: LedgerSnapshot = {
  boards: [
    board(former, 'Company A', [2017, 7], [2019, 8]),
    board(current, 'Company B', [2019, 9]),
  ],
  entries: [
    entry('00000000-0000-4000-8000-0000000000E1', current, {
      name: 'Halve cold start on Android',
      type: 'product',
      link: 'https://example.com/browse/APP-1204',
      date: dayDate(2026, 3, 12),
      endDate: dayDate(2026, 4, 2),
      tags: ['performance', 'android'],
      problem:
        'Launch took **1.8 s** on mid-range phones, and users opened the app many times a day.',
      why: 'Every launch was a wait; reviews named it.',
      solution:
        'Deferred SDK set-up behind the first frame, moved `Room` migrations off the main thread, and added a baseline profile.',
      impact:
        'Cold start p50 from 1.8 s to 0.9 s. See [the write-up](https://example.com/write-up).',
      difficulties: 'Profiling on real devices only; emulators hid the disk cost.',
      metrics: [
        {
          id: '00000000-0000-4000-8000-0000000000A1',
          label: 'Cold start p50',
          before: '1.8',
          after: '0.9',
          unit: 's',
          note: 'Pixel 6a, n=20',
        },
        {
          id: '00000000-0000-4000-8000-0000000000A2',
          label: 'ANR rate',
          before: '0.42',
          after: '0.18',
          unit: '%',
        },
      ],
    }),
    entry('00000000-0000-4000-8000-0000000000E2', current, {
      name: 'Fix crash on resume after process death',
      type: 'bugFix',
      date: dayDate(2025, 12, 30),
      endDate: dayDate(2026, 1, 3),
      problem: 'A null view model after process death.',
      tags: ['stability'],
    }),
    entry('00000000-0000-4000-8000-0000000000E3', current, {
      name: 'Notes on image caching',
      type: 'findings',
      date: dayDate(2026, 5, 20),
    }),
    entry('00000000-0000-4000-8000-0000000000E4', former, {
      name: 'Payments SDK migration',
      date: dayDate(2018, 6, 1),
      solution: 'Wrapped the old SDK, then swapped it per screen.',
    }),
  ],
}

export function makeDemoAppModel(): AppModel {
  const store = new LedgerStore()
  const sync = new SyncLedger(new DemoRemote(sample), ledgerFileCodec)
  return new AppModel({ auth: new DemoAuth(), store, sync, namespace: 'demo' })
}
