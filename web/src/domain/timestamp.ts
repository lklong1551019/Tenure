// Port of Packages/Domain/Sources/Model/Timestamp.swift. Milliseconds since 1970 as an
// integer, so a stamp round-trips exactly through the data file.

/** Milliseconds since 1970. Always a safe integer. */
export type Timestamp = number

export const millisPerDay = 86_400_000

/** Saturates instead of overflowing: a stored value can come from an edited file. */
export function addMillis(stamp: Timestamp, delta: number): Timestamp {
  return Math.min(Math.max(stamp + delta, Number.MIN_SAFE_INTEGER), Number.MAX_SAFE_INTEGER)
}

export function addDays(stamp: Timestamp, days: number): Timestamp {
  return addMillis(stamp, days * millisPerDay)
}

export const isTimestamp = (value: unknown): value is Timestamp => Number.isSafeInteger(value)
