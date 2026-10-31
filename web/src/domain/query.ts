// Port of Packages/Domain/Sources/Query/EntryQuery.swift: which board, which kinds, which
// year, a text filter, and an order. Pure, so the UI only holds the settings.
import { compareDayDate } from './calendar'
import type { Entry, EntryType, Uuid } from './model'
import { matches, terms } from './search'
import { entryYears, touches } from './story'
import { compareNames, compareOrdinal } from './text'

export type EntrySort = 'newest' | 'oldest' | 'nameAscending' | 'nameDescending'

export const entrySorts: readonly EntrySort[] = [
  'newest',
  'oldest',
  'nameAscending',
  'nameDescending',
]

export interface EntryQuery {
  /** Undefined shows every board. */
  readonly boardId?: Uuid
  /** Empty shows every kind, including kinds this build does not know. */
  readonly types: ReadonlySet<EntryType>
  /** Undefined shows every year. A task counts in each year from its date to its end date. */
  readonly year?: number
  readonly text: string
  readonly sort: EntrySort
}

export const defaultQuery: EntryQuery = { types: new Set(), text: '', sort: 'newest' }

export function applyQuery(query: EntryQuery, entries: readonly Entry[]): Entry[] {
  const queryTerms = terms(query.text)
  return entries
    .filter(
      (entry) =>
        (query.boardId === undefined || entry.boardId === query.boardId) &&
        (query.types.size === 0 || query.types.has(entry.type)) &&
        (query.year === undefined || touches(entry, query.year)) &&
        matches(queryTerms, entry),
    )
    .sort((lhs, rhs) => order(query.sort, lhs, rhs))
}

function order(sort: EntrySort, lhs: Entry, rhs: Entry): number {
  const byDate = compareDayDate(lhs.date, rhs.date)
  if (sort === 'newest' && byDate !== 0) return -byDate
  if (sort === 'oldest' && byDate !== 0) return byDate
  const byName = compareNames(lhs.name, rhs.name)
  if (byName !== 0) return sort === 'nameDescending' ? -byName : byName
  // Stable tiebreak, so equal keys never swap places between refreshes.
  return compareOrdinal(lhs.id, rhs.id)
}

/** A year and how many tasks fall in it, for the year menu. */
export interface YearCount {
  readonly year: number
  readonly count: number
}

/** Years with at least one task, newest first; a task spanning two years counts in both. */
export function yearCounts(entries: readonly Entry[]): YearCount[] {
  const counts = new Map<number, number>()
  for (const entry of entries) {
    for (const year of entryYears(entry)) counts.set(year, (counts.get(year) ?? 0) + 1)
  }
  return [...counts]
    .map(([year, count]) => ({ year, count }))
    .sort((lhs, rhs) => rhs.year - lhs.year)
}
