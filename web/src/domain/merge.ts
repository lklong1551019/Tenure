// Port of Packages/Domain/Sources/Merge/MergePolicy.swift. Per item, last writer wins on
// `updatedAt`; ties resolve the same way on every device, so the Mac and the web converge
// whichever merges first.
import { boardJson, entryJson } from './coding'
import type { JsonValue } from './jsonText'
import { writeJson } from './jsonText'
import { type Board, type Entry, type LedgerItem, type LedgerSnapshot, isDeleted } from './model'
import { compareOrdinal } from './text'
import { addDays, type Timestamp } from './timestamp'

/** Long enough for a device offline for a while to receive a delete before it is purged. */
export const tombstoneRetentionDays = 90

export function merge(
  local: LedgerSnapshot,
  remote: LedgerSnapshot,
  now: Timestamp,
  retentionDays = tombstoneRetentionDays,
): LedgerSnapshot {
  return {
    boards: mergeItems(local.boards, remote.boards, boardJson, now, retentionDays),
    entries: mergeItems(local.entries, remote.entries, entryJson, now, retentionDays),
  }
}

export function mergeItems<Item extends Board | Entry>(
  local: readonly Item[],
  remote: readonly Item[],
  json: (item: Item) => JsonValue,
  now: Timestamp,
  retentionDays = tombstoneRetentionDays,
): Item[] {
  const merged = new Map<string, Item>()
  for (const item of [...local, ...remote]) {
    const existing = merged.get(item.id)
    merged.set(item.id, existing ? winner(existing, item, json) : item)
  }
  const cutoff = addDays(now, -retentionDays)
  return [...merged.values()]
    .filter((item) => !(isDeleted(item) && item.updatedAt < cutoff))
    .sort((lhs, rhs) => compareOrdinal(lhs.id, rhs.id))
}

export function winner<Item extends LedgerItem>(
  lhs: Item,
  rhs: Item,
  json: (item: Item) => JsonValue,
): Item {
  if (lhs.updatedAt !== rhs.updatedAt) return lhs.updatedAt > rhs.updatedAt ? lhs : rhs
  // Same instant: a delete beats an edit, then the larger canonical encoding wins. Both rules
  // are symmetric, which is what makes merge order irrelevant.
  if (isDeleted(lhs) !== isDeleted(rhs)) return isDeleted(lhs) ? lhs : rhs
  return compareBytes(canonical(json(lhs)), canonical(json(rhs))) < 0 ? rhs : lhs
}

const encoder = new TextEncoder()

/** UTF-8 bytes of Swift's `.sortedKeys` encoding: the order `Data` compares in. */
const canonical = (value: JsonValue) => encoder.encode(writeJson(value, 'canonical'))

function compareBytes(lhs: Uint8Array, rhs: Uint8Array): number {
  const length = Math.min(lhs.length, rhs.length)
  for (let index = 0; index < length; index++) {
    const difference = (lhs[index] as number) - (rhs[index] as number)
    if (difference !== 0) return difference
  }
  return lhs.length - rhs.length
}
