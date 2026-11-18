import type { YearMonth } from '../../domain/calendar'
import type { Entry } from '../../domain/model'
import type { EntrySort } from '../../domain/query'

/** Tasks under one heading in the grid or list: the month they start in, in the order shown. */
export interface EntryGroup {
  /** Undefined when the tasks are sorted by name: the group has no heading. */
  month?: YearMonth
  entries: Entry[]
}

/**
 * Consecutive tasks that start in the same month share a group, so date order is kept; sorted
 * by name, one group without a heading. The same rule as `EntryGroup.groups` on the Mac.
 */
export function entryGroups(entries: readonly Entry[], sort: EntrySort): EntryGroup[] {
  if (entries.length === 0) return []
  if (sort === 'nameAscending' || sort === 'nameDescending') return [{ entries: [...entries] }]
  const groups: EntryGroup[] = []
  for (const entry of entries) {
    const last = groups.at(-1)
    if (last?.month?.year === entry.date.year && last.month.month === entry.date.month) {
      last.entries.push(entry)
    } else {
      groups.push({ month: { year: entry.date.year, month: entry.date.month }, entries: [entry] })
    }
  }
  return groups
}
