// Port of Packages/Domain/Sources/Model: Board, Entry, Metric, LedgerItem, LedgerSnapshot.
// Plain readonly data; every change makes a new value (see ledgerStore.ts).
import { compareYearMonth, type DayDate, type YearMonth } from './calendar'
import { compareNames } from './text'
import type { Timestamp } from './timestamp'

/** An uppercase UUID string, as Swift's `UUID.uuidString` writes it. */
export type Uuid = string

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

/** `UUID(uuidString:)`: any case in, uppercase out; undefined when it is not a UUID. */
export function parseUuid(text: string): Uuid | undefined {
  return uuidPattern.test(text) ? text.toUpperCase() : undefined
}

export const newUuid = (): Uuid => crypto.randomUUID().toUpperCase()

/** What sync and merge need from a board or an entry. A delete keeps the item as a tombstone. */
export interface LedgerItem {
  readonly id: Uuid
  readonly updatedAt: Timestamp
  readonly deletedAt?: Timestamp
}

export const isDeleted = (item: LedgerItem) => item.deletedAt !== undefined

/** One stretch of a career, usually one company. */
export interface Board extends LedgerItem {
  readonly name: string
  readonly start: YearMonth
  /** Undefined while it is still the current one. */
  readonly end?: YearMonth
  readonly createdAt: Timestamp
}

/**
 * Kind of work. An open string rather than a closed union, so a kind written by a newer
 * build survives a round trip.
 */
export type EntryType = string

export const EntryTypes = {
  product: 'product',
  dev: 'dev',
  bugFix: 'bugFix',
  findings: 'findings',
} as const

export const knownEntryTypes: readonly EntryType[] = Object.values(EntryTypes)

/** "Bug fix" for the known kinds; an unknown kind shows as written, first letter raised. */
export function entryTypeTitle(type: EntryType): string {
  switch (type) {
    case EntryTypes.product:
      return 'Product'
    case EntryTypes.dev:
      return 'Dev'
    case EntryTypes.bugFix:
      return 'Bug fix'
    case EntryTypes.findings:
      return 'Findings'
    default: {
      const [first = '', ...rest] = Array.from(type)
      return first.toUpperCase() + rest.join('')
    }
  }
}

/** A number worth quoting later. Values stay text: "p50", "~40%", "1.2k req/s". */
export interface Metric {
  readonly id: Uuid
  readonly label: string
  readonly before?: string
  readonly after: string
  readonly unit?: string
  /** How it was measured: device, sample size, time window. */
  readonly note?: string
}

/** One thing done; the UI calls it a task. */
export interface Entry extends LedgerItem {
  readonly boardId: Uuid
  readonly name: string
  /** Ticket or document link, kept as typed: it may not be a valid URL. */
  readonly link?: string
  readonly type: EntryType
  readonly date: DayDate
  /** Last day, for work that spanned a while. */
  readonly endDate?: DayDate
  readonly tags: readonly string[]
  readonly problem: string
  readonly why: string
  readonly solution: string
  readonly impact: string
  readonly difficulties: string
  readonly metrics: readonly Metric[]
  readonly createdAt: Timestamp
}

/** Everything stored, live items and tombstones alike. */
export interface LedgerSnapshot {
  readonly boards: readonly Board[]
  readonly entries: readonly Entry[]
}

export const emptySnapshot: LedgerSnapshot = { boards: [], entries: [] }

/** Newest start first; ties by name. */
export function timelineOrder(lhs: Board, rhs: Board): number {
  return compareYearMonth(rhs.start, lhs.start) || compareNames(lhs.name, rhs.name)
}

export function liveBoards(snapshot: LedgerSnapshot): Board[] {
  return snapshot.boards.filter((board) => !isDeleted(board)).sort(timelineOrder)
}

/** Live entries on live boards. */
export function liveEntries(snapshot: LedgerSnapshot): Entry[] {
  const boardIds = new Set(snapshot.boards.filter((board) => !isDeleted(board)).map((b) => b.id))
  return snapshot.entries.filter((entry) => !isDeleted(entry) && boardIds.has(entry.boardId))
}
