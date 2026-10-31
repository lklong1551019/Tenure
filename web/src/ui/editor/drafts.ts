// What the editors hold while the user types, and the rules for turning it into a board or a
// task: ports of BoardDraft (Board/BoardViewModel.swift) and EntryEditorViewModel.swift, so
// both apps validate and normalize alike.
import {
  compareDayDate,
  compareYearMonth,
  type DayDate,
  formatDayDate,
  formatYearMonth,
  parseDayDate,
  parseYearMonth,
  type YearMonth,
} from '../../domain/calendar'
import { type Board, type Entry, type Metric, newUuid } from '../../domain/model'
import { trimmingWhitespace, trimmingWhitespaceAndNewlines } from '../../domain/text'

export interface BoardDraft {
  readonly original?: Board
  name: string
  /** "2017-07", as <input type="month"> holds it. */
  start: string
  isCurrent: boolean
  end: string
}

export function boardDraft(board: Board | undefined, today: YearMonth): BoardDraft {
  return {
    original: board,
    name: board?.name ?? '',
    start: formatYearMonth(board?.start ?? today),
    isCurrent: board ? board.end === undefined : true,
    end: formatYearMonth(board?.end ?? today),
  }
}

/** Undefined when it can be saved. */
export function boardProblem(draft: BoardDraft): string | undefined {
  const start = parseYearMonth(draft.start)
  const end = parseYearMonth(draft.end)
  if (trimmingWhitespace(draft.name) === '') return 'Enter a name.'
  if (!start) return 'Enter a start month.'
  if (!draft.isCurrent && !end) return 'Enter an end month.'
  if (!draft.isCurrent && end && compareYearMonth(end, start) < 0)
    return 'The end comes before the start.'
  return undefined
}

/** The board to store; `updatedAt` is set by the store. */
export function boardFromDraft(draft: BoardDraft, now: number): Board {
  const end = draft.isCurrent ? undefined : parseYearMonth(draft.end)
  return {
    id: draft.original?.id ?? newUuid(),
    name: trimmingWhitespace(draft.name),
    start: parseYearMonth(draft.start)!,
    ...(end && { end }),
    createdAt: draft.original?.createdAt ?? now,
    updatedAt: draft.original?.updatedAt ?? now,
  }
}

export interface MetricDraft {
  /** Kept from the stored metric, so an edit does not look like a new metric. */
  readonly id: string
  label: string
  before: string
  after: string
  unit: string
  note: string
}

export interface EntryDraft {
  readonly original?: Entry
  boardId: string
  name: string
  link: string
  type: string
  /** "2026-03-12", as <input type="date"> holds it. */
  date: string
  hasEndDate: boolean
  endDate: string
  /** "ios, perf, ci". */
  tags: string
  problem: string
  why: string
  solution: string
  impact: string
  difficulties: string
  metrics: MetricDraft[]
}

export function entryDraft(entry: Entry | undefined, boardId: string, today: DayDate): EntryDraft {
  return {
    original: entry,
    boardId: entry?.boardId ?? boardId,
    name: entry?.name ?? '',
    link: entry?.link ?? '',
    type: entry?.type ?? 'dev',
    date: formatDayDate(entry?.date ?? today),
    hasEndDate: entry?.endDate !== undefined,
    endDate: formatDayDate(entry?.endDate ?? entry?.date ?? today),
    tags: entry?.tags.join(', ') ?? '',
    problem: entry?.problem ?? '',
    why: entry?.why ?? '',
    solution: entry?.solution ?? '',
    impact: entry?.impact ?? '',
    difficulties: entry?.difficulties ?? '',
    metrics: (entry?.metrics ?? []).map(metricDraft),
  }
}

export function metricDraft(metric?: Metric): MetricDraft {
  return {
    id: metric?.id ?? newUuid(),
    label: metric?.label ?? '',
    before: metric?.before ?? '',
    after: metric?.after ?? '',
    unit: metric?.unit ?? '',
    note: metric?.note ?? '',
  }
}

const trimmed = trimmingWhitespaceAndNewlines

const isBlank = (metric: MetricDraft) =>
  [metric.label, metric.before, metric.after, metric.unit, metric.note].every(
    (value) => trimmingWhitespace(value) === '',
  )

/** Undefined when it can be saved. */
export function entryProblem(draft: EntryDraft): string | undefined {
  const date = parseDayDate(draft.date)
  const endDate = parseDayDate(draft.endDate)
  if (trimmed(draft.name) === '') return 'Enter a name.'
  if (draft.boardId === '') return 'Choose a board.'
  if (!date) return 'Enter a date.'
  if (draft.hasEndDate && !endDate) return 'Enter an end date.'
  if (draft.hasEndDate && endDate && compareDayDate(endDate, date) < 0) {
    return 'The end date comes before the start.'
  }
  if (
    draft.metrics.some((m) => !isBlank(m) && (trimmed(m.label) === '' || trimmed(m.after) === ''))
  ) {
    return 'Each metric needs a label and an after value.'
  }
  return undefined
}

/** "ios, perf ,  #ci,ios" becomes ["ios", "perf", "ci"]. */
export function parseTags(text: string): string[] {
  const seen = new Set<string>()
  return text
    .split(',')
    .map((tag) => trimmingWhitespace(tag).replace(/^#+|#+$/g, ''))
    .filter((tag) => {
      const key = tag.toLowerCase()
      if (tag === '' || seen.has(key)) return false
      seen.add(key)
      return true
    })
}

/** The task to store; `updatedAt` is set by the store. */
export function entryFromDraft(draft: EntryDraft, now: number): Entry {
  const link = trimmed(draft.link)
  const endDate = draft.hasEndDate ? parseDayDate(draft.endDate) : undefined
  return {
    id: draft.original?.id ?? newUuid(),
    boardId: draft.boardId,
    name: trimmed(draft.name),
    ...(link !== '' && { link }),
    type: draft.type,
    date: parseDayDate(draft.date)!,
    ...(endDate && { endDate }),
    tags: parseTags(draft.tags),
    problem: trimmed(draft.problem),
    why: trimmed(draft.why),
    solution: trimmed(draft.solution),
    impact: trimmed(draft.impact),
    difficulties: trimmed(draft.difficulties),
    metrics: draft.metrics.filter((m) => !isBlank(m)).map(metricFromDraft),
    createdAt: draft.original?.createdAt ?? now,
    updatedAt: draft.original?.updatedAt ?? now,
  }
}

function metricFromDraft(draft: MetricDraft): Metric {
  const optional = (value: string) => (trimmed(value) === '' ? undefined : trimmed(value))
  const before = optional(draft.before)
  const unit = optional(draft.unit)
  const note = optional(draft.note)
  return {
    id: draft.id,
    label: trimmed(draft.label),
    ...(before !== undefined && { before }),
    after: trimmed(draft.after),
    ...(unit !== undefined && { unit }),
    ...(note !== undefined && { note }),
  }
}
