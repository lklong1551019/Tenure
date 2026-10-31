// The JSON shape of boards, entries, and metrics: the Codable conformances in
// Packages/Domain/Sources/Model. Decoding is tolerant inside items: a missing or malformed
// field falls back to a default, and only `id`, `boardId`, and `updatedAt` are required.
import {
  dayDateOf,
  formatDayDate,
  formatYearMonth,
  parseDayDate,
  parseYearMonth,
  yearMonthOf,
} from './calendar'
import type { JsonValue } from './jsonText'
import { type Board, type Entry, type Metric, newUuid, parseUuid } from './model'
import { isTimestamp } from './timestamp'

/** An item that cannot be read at all: the whole file is then refused. */
export class ItemDecodingError extends Error {
  constructor(what: string) {
    super(`unreadable ${what}`)
    this.name = 'ItemDecodingError'
  }
}

type JsonObject = { readonly [key: string]: unknown }

export const isObject = (value: unknown): value is JsonObject =>
  typeof value === 'object' && value !== null && !Array.isArray(value)

// `container.lenient(...)`: the value when it has the right type, otherwise undefined.
const string = (value: unknown) => (typeof value === 'string' ? value : undefined)
const uuid = (value: unknown) => (typeof value === 'string' ? parseUuid(value) : undefined)
const stamp = (value: unknown) => (isTimestamp(value) ? value : undefined)
const month = (value: unknown) => (typeof value === 'string' ? parseYearMonth(value) : undefined)
const day = (value: unknown) => (typeof value === 'string' ? parseDayDate(value) : undefined)
const strings = (value: unknown) =>
  Array.isArray(value) && value.every((item) => typeof item === 'string')
    ? (value as string[])
    : undefined
// One element that is not an object fails the whole array in Swift, so it does here.
const metrics = (value: unknown) =>
  Array.isArray(value) && value.every(isObject) ? value.map(decodeMetric) : undefined

function required<Value>(value: Value | undefined, what: string): Value {
  if (value === undefined) throw new ItemDecodingError(what)
  return value
}

export function decodeBoard(value: unknown): Board {
  if (!isObject(value)) throw new ItemDecodingError('board')
  const id = required(uuid(value.id), 'board id')
  const updatedAt = required(stamp(value.updatedAt), 'board updatedAt')
  return withoutUndefined({
    id,
    name: string(value.name) ?? '',
    start: month(value.start) ?? yearMonthOf(updatedAt),
    end: month(value.end),
    createdAt: stamp(value.createdAt) ?? updatedAt,
    updatedAt,
    deletedAt: stamp(value.deletedAt),
  })
}

export function decodeEntry(value: unknown): Entry {
  if (!isObject(value)) throw new ItemDecodingError('entry')
  const id = required(uuid(value.id), 'entry id')
  const boardId = required(uuid(value.boardId), 'entry boardId')
  const updatedAt = required(stamp(value.updatedAt), 'entry updatedAt')
  return withoutUndefined({
    id,
    boardId,
    name: string(value.name) ?? '',
    link: string(value.link),
    type: string(value.type) ?? 'dev',
    date: day(value.date) ?? dayDateOf(updatedAt),
    endDate: day(value.endDate),
    tags: strings(value.tags) ?? [],
    problem: string(value.problem) ?? '',
    why: string(value.why) ?? '',
    solution: string(value.solution) ?? '',
    impact: string(value.impact) ?? '',
    difficulties: string(value.difficulties) ?? '',
    metrics: metrics(value.metrics) ?? [],
    createdAt: stamp(value.createdAt) ?? updatedAt,
    updatedAt,
    deletedAt: stamp(value.deletedAt),
  })
}

export function decodeMetric(value: JsonObject): Metric {
  return withoutUndefined({
    // A metric without a readable id gets a new one, as on the Mac.
    id: uuid(value.id) ?? newUuid(),
    label: string(value.label) ?? '',
    before: string(value.before),
    after: string(value.after) ?? '',
    unit: string(value.unit),
    note: string(value.note),
  })
}

export function boardJson(board: Board): JsonValue {
  return {
    id: board.id,
    name: board.name,
    start: formatYearMonth(board.start),
    end: board.end && formatYearMonth(board.end),
    createdAt: board.createdAt,
    updatedAt: board.updatedAt,
    deletedAt: board.deletedAt,
  }
}

export function entryJson(entry: Entry): JsonValue {
  return {
    id: entry.id,
    boardId: entry.boardId,
    name: entry.name,
    link: entry.link,
    type: entry.type,
    date: formatDayDate(entry.date),
    endDate: entry.endDate && formatDayDate(entry.endDate),
    tags: entry.tags,
    problem: entry.problem,
    why: entry.why,
    solution: entry.solution,
    impact: entry.impact,
    difficulties: entry.difficulties,
    metrics: entry.metrics.map(metricJson),
    createdAt: entry.createdAt,
    updatedAt: entry.updatedAt,
    deletedAt: entry.deletedAt,
  }
}

export function metricJson(metric: Metric): JsonValue {
  return {
    id: metric.id,
    label: metric.label,
    before: metric.before,
    after: metric.after,
    unit: metric.unit,
    note: metric.note,
  }
}

/** Optional fields are absent rather than present-and-undefined, so values compare simply. */
function withoutUndefined<Value extends object>(value: Value): Value {
  for (const key of Object.keys(value) as (keyof Value)[]) {
    if (value[key] === undefined) delete value[key]
  }
  return value
}
