// Foundation's character sets and comparisons that the ported rules rely on.

/** `CharacterSet.whitespaces`: space separators and tab. */
const whitespace = '\\t\\p{Zs}'
/** `CharacterSet.newlines`. */
const newline = '\\n\\r\\u000B\\u000C\\u0085\\u2028\\u2029'

const trimWhitespace = new RegExp(`^[${whitespace}]+|[${whitespace}]+$`, 'gu')
const trimWhitespaceAndNewlines = new RegExp(
  `^[${whitespace}${newline}]+|[${whitespace}${newline}]+$`,
  'gu',
)

/** `trimmingCharacters(in: .whitespaces)`. */
export const trimmingWhitespace = (text: string) => text.replace(trimWhitespace, '')

/** `trimmingCharacters(in: .whitespacesAndNewlines)`. */
export const trimmingWhitespaceAndNewlines = (text: string) =>
  text.replace(trimWhitespaceAndNewlines, '')

/** `components(separatedBy: .newlines)`. */
export const lines = (text: string) => text.split(new RegExp(`[${newline}]`, 'u'))

const collator = new Intl.Collator(undefined, { numeric: true })

/**
 * Stand-in for `localizedStandardCompare`: the reader's language, digits compared as numbers
 * ("Task 2" before "Task 10"). It only orders names for display, never decides data.
 */
export const compareNames = (lhs: string, rhs: string) => collator.compare(lhs, rhs)

/** Swift's `<` on ASCII strings such as UUIDs: code unit order. */
export const compareOrdinal = (lhs: string, rhs: string) => (lhs < rhs ? -1 : lhs > rhs ? 1 : 0)
