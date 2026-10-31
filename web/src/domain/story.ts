// Port of Packages/Domain/Sources/Model/Entry+Story.swift: the five-part story, periods,
// years, counts, and metric changes.
import { type DayDate, type YearMonth, sameDay } from './calendar'
import type { Board, Entry, Metric } from './model'
import { trimmingWhitespace, trimmingWhitespaceAndNewlines } from './text'

export type StoryPart = 'problem' | 'why' | 'solution' | 'impact' | 'difficulties'

/** The five parts in the order they are told. */
export const storyParts: readonly StoryPart[] = [
  'problem',
  'why',
  'solution',
  'impact',
  'difficulties',
]

export const storyPartTitles: Record<StoryPart, string> = {
  problem: 'Problem',
  why: 'Why',
  solution: 'Solution',
  impact: 'Impact',
  difficulties: 'Difficulties and how they were solved',
}

/** The story parts in order, empty ones left out. */
export function story(entry: Entry): { part: StoryPart; text: string }[] {
  return storyParts
    .map((part) => ({ part, text: entry[part] }))
    .filter(({ text }) => trimmingWhitespaceAndNewlines(text) !== '')
}

/** The name, or "Untitled" when it is empty. */
export const displayName = (entry: Entry) => (entry.name === '' ? 'Untitled' : entry.name)

/** "12 Mar 2026", or "12 Mar 2026 - 20 Mar 2026" for a span; `format` writes one day. */
export function entryPeriod(entry: Entry, format: (day: DayDate) => string): string {
  if (!entry.endDate || sameDay(entry.endDate, entry.date)) return format(entry.date)
  return `${format(entry.date)} - ${format(entry.endDate)}`
}

/** The years from its date to its end date. */
export function entryYears(entry: Entry): number[] {
  const first = entry.date.year
  const last = Math.max(first, entry.endDate?.year ?? first)
  return Array.from({ length: last - first + 1 }, (_, index) => first + index)
}

/** Whether any day from its date to its end date falls in `year`. */
export function touches(entry: Entry, year: number): boolean {
  return year >= entry.date.year && year <= Math.max(entry.date.year, entry.endDate?.year ?? 0)
}

/** "Jul 2017 - Aug 2019", or "Sep 2019 - now"; `format` writes one month. */
export function boardPeriod(board: Board, format: (month: YearMonth) => string): string {
  return `${format(board.start)} - ${board.end ? format(board.end) : 'now'}`
}

/** "1 task", "3 tasks". */
export const counted = (count: number, noun: string) =>
  count === 1 ? `1 ${noun}` : `${count} ${noun}s`

/**
 * Swift's `Double(String)` for the plain decimals people type: "1,200" and " 18 " read as
 * numbers, "18ms" and "p50" do not.
 */
function metricNumber(text: string): number | undefined {
  const cleaned = trimmingWhitespace(text.replaceAll(',', ''))
  if (!/^[+-]?([0-9]+\.?[0-9]*|\.[0-9]+)([eE][+-]?[0-9]+)?$/.test(cleaned)) return undefined
  return Number(cleaned)
}

/** Change from before to after as a fraction: -0.44 for 18 to 10. */
export function metricChange(metric: Metric): number | undefined {
  const before = metric.before === undefined ? undefined : metricNumber(metric.before)
  const after = metricNumber(metric.after)
  if (before === undefined || after === undefined || before === 0) return undefined
  return (after - before) / Math.abs(before)
}

/** Swift's `rounded()`: halves away from zero. */
const roundHalfAway = (value: number) => Math.sign(value) * Math.round(Math.abs(value))

/** "-44%", "+12%", "+0.5%". */
export function metricChangeText(metric: Metric): string | undefined {
  const change = metricChange(metric)
  if (change === undefined) return undefined
  const percent = change * 100
  const rounded =
    Math.abs(percent) >= 10 ? roundHalfAway(percent) : roundHalfAway(percent * 10) / 10
  const digits = String(Number.isInteger(rounded) ? Math.trunc(rounded) + 0 : rounded)
  return (rounded > 0 ? '+' : '') + digits + '%'
}

/** "18 ms"; the value alone when there is no unit. */
export function withUnit(metric: Metric, value: string): string {
  if (metric.unit === undefined || trimmingWhitespace(metric.unit) === '') return value
  return `${value} ${metric.unit}`
}
