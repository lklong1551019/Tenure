// Port of Packages/Domain/Sources/Search/EntrySearch.swift. Ranks entries by name, tags,
// link, and kind. The write-up is left out on purpose: a short query would match half the
// ledger through common words.
import type { Entry } from './model'
import { compareNames, trimmingWhitespaceAndNewlines } from './text'

/** Case, diacritic, and width insensitive, so "viet" finds "Việt". */
export function normalize(text: string): string {
  const folded = text
    .normalize('NFKD')
    .replace(/\p{Mn}/gu, '')
    .toLowerCase()
    .normalize('NFC')
  return trimmingWhitespaceAndNewlines(folded)
}

/** The query split on spaces, empty pieces dropped. */
export function terms(query: string): string[] {
  return normalize(query)
    .split(' ')
    .filter((term) => term.length > 0)
}

export function search(query: string, entries: readonly Entry[]): Entry[] {
  const queryTerms = terms(query)
  if (queryTerms.length === 0) return [...entries]
  return entries
    .flatMap((entry) => {
      const value = score(queryTerms, entry)
      return value === undefined ? [] : [{ entry, value }]
    })
    .sort((lhs, rhs) => rhs.value - lhs.value || compareNames(lhs.entry.name, rhs.entry.name))
    .map(({ entry }) => entry)
}

/** Whether every term matches; no terms match everything. */
export function matches(queryTerms: readonly string[], entry: Entry): boolean {
  return queryTerms.length === 0 || score(queryTerms, entry) !== undefined
}

function score(queryTerms: readonly string[], entry: Entry): number | undefined {
  const name = normalize(entry.name)
  let total = 0
  for (const term of queryTerms) {
    const value = termScore(term, entry, name)
    if (value === undefined) return undefined
    total += value
  }
  return total
}

/** `name` is the entry's name, normalized once for all terms. */
function termScore(term: string, entry: Entry, name: string): number | undefined {
  if (name.startsWith(term)) return 100
  if (name.split(' ').some((word) => word.length > 0 && word.startsWith(term))) return 80
  if (name.includes(term)) return 60
  if (entry.tags.some((tag) => normalize(tag).startsWith(term))) return 40
  if (normalize(entry.link ?? '').includes(term)) return 30
  if (normalize(entry.type).startsWith(term)) return 20
  if (isSubsequence(term, name)) return 10
  return undefined
}

function isSubsequence(needle: string, haystack: string): boolean {
  const remaining = Array.from(needle)
  let index = 0
  for (const character of haystack) {
    if (character === remaining[index]) index++
    if (index === remaining.length) return true
  }
  return index === remaining.length
}
