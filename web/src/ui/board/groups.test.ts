import { describe, expect, it } from 'vitest'
import type { Entry } from '../../domain/model'
import { entryGroups } from './groups'

const task = (id: string, year: number, month: number, day: number) =>
  ({ id, date: { year, month, day } }) as Entry

// The same cases as `groupsByStartMonthWhenSortedByDate` in the Mac's BoardFeatureTests.
describe('entryGroups', () => {
  const newest = [
    task('crash', 2025, 11, 2),
    task('later', 2025, 6, 28),
    task('onboarding', 2025, 6, 20),
    task('ci', 2018, 5, 10),
  ]

  it('groups by start month when sorted by date', () => {
    const groups = entryGroups(newest, 'newest')
    expect(groups.map((group) => group.month)).toEqual([
      { year: 2025, month: 11 },
      { year: 2025, month: 6 },
      { year: 2018, month: 5 },
    ])
    expect(groups[1]?.entries.map((entry) => entry.id)).toEqual(['later', 'onboarding'])
  })

  it('keeps one group without a heading when sorted by name', () => {
    const groups = entryGroups(newest, 'nameAscending')
    expect(groups).toHaveLength(1)
    expect(groups[0]?.month).toBeUndefined()
    expect(groups[0]?.entries).toEqual(newest)
  })

  it('has no group without tasks', () => {
    expect(entryGroups([], 'newest')).toEqual([])
  })
})
