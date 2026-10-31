import { describe, expect, it } from 'vitest'
import { fixture } from '../../test/fixtures'
import { ledgerFileCodec as codec } from '../data/ledgerFileCodec'
import { liveEntries } from './model'
import { applyQuery, type EntrySort, yearCounts } from './query'
import { search } from './search'

interface QueryFixture {
  file: string
  queries: {
    name: string
    boardId?: string
    types: string[]
    year?: number
    text: string
    sort: EntrySort
    result: string[]
  }[]
  searches: { text: string; result: string[] }[]
}

const data = fixture<QueryFixture>('query-cases.json')
const entries = liveEntries(codec.decode(data.file))

describe('applyQuery against EntryQuery', () => {
  it.each(data.queries.map((c) => [c.name, c] as const))('%s', (_, queryCase) => {
    const result = applyQuery(
      {
        boardId: queryCase.boardId,
        types: new Set(queryCase.types),
        year: queryCase.year,
        text: queryCase.text,
        sort: queryCase.sort,
      },
      entries,
    )
    expect(result.map((entry) => entry.id)).toEqual(queryCase.result)
  })
})

describe('search against EntrySearch', () => {
  it.each(data.searches.map((c) => [JSON.stringify(c.text), c] as const))('%s', (_, searchCase) => {
    expect(search(searchCase.text, entries).map((entry) => entry.id)).toEqual(searchCase.result)
  })
})

describe('yearCounts', () => {
  it('counts a task in every year it spans, newest first', () => {
    expect(yearCounts(entries)).toEqual([
      { year: 2026, count: 3 },
      { year: 2025, count: 1 },
      { year: 2018, count: 4 },
    ])
  })
})
