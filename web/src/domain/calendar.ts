// Port of Packages/Domain/Sources/Model/CalendarDates.swift. Calendar values with no time
// zone, stored as "2017-07" and "2026-03-12", so every device shows the same month and day.

/** Years a date may carry; anything outside reads as invalid (a typo such as "20250"). */
export const validYears = { lowerBound: 1, upperBound: 9999 } as const

/** A calendar month, such as the start of a job. */
export interface YearMonth {
  readonly year: number
  readonly month: number
}

/** A calendar day, such as the day a task shipped. */
export interface DayDate {
  readonly year: number
  readonly month: number
  readonly day: number
}

const clamp = (value: number, low: number, high: number) => Math.min(Math.max(value, low), high)

export function yearMonth(year: number, month: number): YearMonth {
  return {
    year: clamp(year, validYears.lowerBound, validYears.upperBound),
    month: clamp(month, 1, 12),
  }
}

export function dayDate(year: number, month: number, day: number): DayDate {
  return {
    year: clamp(year, validYears.lowerBound, validYears.upperBound),
    month: clamp(month, 1, 12),
    day: clamp(day, 1, 31),
  }
}

/**
 * Swift's `Int(String)`: optional sign, ASCII digits, nothing else. Values past Int64 are nil
 * there; here they are simply out of every valid range.
 */
function integer(text: string): number | undefined {
  return /^[+-]?[0-9]+$/.test(text) ? Number(text) : undefined
}

/** Swift's `split(separator: "-")`, which drops empty pieces: "2017--07" has two parts. */
function parts(text: string): number[] | undefined {
  const values = text
    .split('-')
    .filter((part) => part.length > 0)
    .map(integer)
  return values.every((value) => value !== undefined) ? (values as number[]) : undefined
}

const isValidYear = (year: number) => year >= validYears.lowerBound && year <= validYears.upperBound

/** "2017-07"; undefined for anything else. */
export function parseYearMonth(text: string): YearMonth | undefined {
  const values = parts(text)
  if (values?.length !== 2) return undefined
  const [year, month] = values as [number, number]
  if (!isValidYear(year) || month < 1 || month > 12) return undefined
  return yearMonth(year, month)
}

/** "2026-03-12"; undefined for anything else. The day is not checked against the month. */
export function parseDayDate(text: string): DayDate | undefined {
  const values = parts(text)
  if (values?.length !== 3) return undefined
  const [year, month, day] = values as [number, number, number]
  if (!isValidYear(year) || month < 1 || month > 12 || day < 1 || day > 31) return undefined
  return dayDate(year, month, day)
}

const pad = (value: number, width: number) => String(value).padStart(width, '0')

export const formatYearMonth = (value: YearMonth) => `${pad(value.year, 4)}-${pad(value.month, 2)}`

export const formatDayDate = (value: DayDate) =>
  `${pad(value.year, 4)}-${pad(value.month, 2)}-${pad(value.day, 2)}`

/** Negative, zero, or positive, like a sort comparator. */
export function compareYearMonth(lhs: YearMonth, rhs: YearMonth): number {
  return lhs.year - rhs.year || lhs.month - rhs.month
}

export function compareDayDate(lhs: DayDate, rhs: DayDate): number {
  return lhs.year - rhs.year || lhs.month - rhs.month || lhs.day - rhs.day
}

export const sameDay = (lhs: DayDate, rhs: DayDate) => compareDayDate(lhs, rhs) === 0

/** The month of a moment in this device's time zone, as `YearMonth(Date)` does on the Mac. */
export function yearMonthOf(millis: number): YearMonth {
  const date = new Date(millis)
  if (Number.isNaN(date.getTime())) return yearMonth(1970, 1)
  return yearMonth(date.getFullYear(), date.getMonth() + 1)
}

/** The day of a moment in this device's time zone. */
export function dayDateOf(millis: number): DayDate {
  const date = new Date(millis)
  if (Number.isNaN(date.getTime())) return dayDate(1970, 1, 1)
  return dayDate(date.getFullYear(), date.getMonth() + 1, date.getDate())
}
