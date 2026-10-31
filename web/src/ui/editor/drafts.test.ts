import { describe, expect, it } from 'vitest'
import { dayDate, yearMonth } from '../../domain/calendar'
import {
  boardDraft,
  boardFromDraft,
  boardProblem,
  entryDraft,
  entryFromDraft,
  entryProblem,
  metricDraft,
  parseTags,
} from './drafts'

describe('board drafts', () => {
  it('needs a name and a range that runs forward', () => {
    const draft = boardDraft(undefined, yearMonth(2026, 10))
    expect(boardProblem(draft)).toBe('Enter a name.')
    draft.name = '  Company A '
    expect(boardProblem(draft)).toBeUndefined()
    draft.isCurrent = false
    draft.end = '2026-01'
    expect(boardProblem(draft)).toBe('The end comes before the start.')
    draft.end = '2027-02'
    expect(boardFromDraft(draft, 5)).toMatchObject({
      name: 'Company A',
      start: { year: 2026, month: 10 },
      end: { year: 2027, month: 2 },
      createdAt: 5,
    })
  })

  it('keeps the id and createdAt of the board it edits, and drops the end when current', () => {
    const board = {
      id: 'B',
      name: 'x',
      start: yearMonth(2017, 7),
      end: yearMonth(2019, 8),
      createdAt: 1,
      updatedAt: 2,
    }
    const draft = boardDraft(board, yearMonth(2026, 1))
    draft.isCurrent = true
    const saved = boardFromDraft(draft, 99)
    expect(saved.id).toBe('B')
    expect(saved.createdAt).toBe(1)
    expect('end' in saved).toBe(false)
  })
})

describe('entry drafts', () => {
  it('validates like the Mac editor', () => {
    const draft = entryDraft(undefined, 'B', dayDate(2026, 3, 12))
    expect(entryProblem(draft)).toBe('Enter a name.')
    draft.name = 'Task'
    expect(entryProblem(draft)).toBeUndefined()
    draft.hasEndDate = true
    draft.endDate = '2026-03-11'
    expect(entryProblem(draft)).toBe('The end date comes before the start.')
    draft.hasEndDate = false
    draft.metrics = [{ ...metricDraft(), before: '1' }]
    expect(entryProblem(draft)).toBe('Each metric needs a label and an after value.')
  })

  it('trims, drops blank metrics, and leaves empty optionals out', () => {
    const draft = entryDraft(undefined, 'B', dayDate(2026, 3, 12))
    Object.assign(draft, {
      name: ' Task \n',
      link: '  ',
      tags: 'ios, perf ,  #ci,IOS',
      problem: '\n p \n',
    })
    draft.metrics = [
      { ...metricDraft(), label: ' Cold start ', before: ' ', after: '0.9', unit: 's' },
      metricDraft(),
    ]
    const entry = entryFromDraft(draft, 7)
    expect(entry).toMatchObject({
      name: 'Task',
      tags: ['ios', 'perf', 'ci'],
      problem: 'p',
      createdAt: 7,
    })
    expect('link' in entry).toBe(false)
    expect('endDate' in entry).toBe(false)
    expect(entry.metrics).toHaveLength(1)
    expect(entry.metrics[0]).toEqual({
      id: draft.metrics[0]!.id,
      label: 'Cold start',
      after: '0.9',
      unit: 's',
    })
  })

  it('parses tags as the Mac does', () => {
    expect(parseTags('ios, perf ,  ci,ios')).toEqual(['ios', 'perf', 'ci'])
    expect(parseTags(' , #, ##x#')).toEqual(['x'])
  })
})
