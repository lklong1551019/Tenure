// Port of `SnapshotFingerprint` (Packages/Domain/Sources/Sync/SyncTypes.swift): FNV-1a over
// item ids, stamps, and delete flags. Every content change moves `updatedAt`, so equal
// fingerprints mean equal content.
import { type LedgerItem, type LedgerSnapshot, isDeleted } from './model'
import { compareOrdinal } from './text'

const offsetBasis = 0xcbf29ce484222325n
const prime = 0x100000001b3n
const mask = 0xffffffffffffffffn
const encoder = new TextEncoder()

/** A 64-bit value, as a bigint: a number cannot hold it exactly. */
export function fingerprint(snapshot: LedgerSnapshot): bigint {
  let hash = offsetBasis
  const mix = (text: string) => {
    for (const byte of encoder.encode(text)) {
      hash = ((hash ^ BigInt(byte)) * prime) & mask
    }
  }
  const sorted = <Item extends LedgerItem>(items: readonly Item[]) =>
    [...items].sort((lhs, rhs) => compareOrdinal(lhs.id, rhs.id))
  for (const board of sorted(snapshot.boards)) {
    mix(`|b|${board.id}|${board.updatedAt}|${isDeleted(board)}`)
  }
  for (const entry of sorted(snapshot.entries)) {
    mix(`|e|${entry.id}|${entry.updatedAt}|${isDeleted(entry)}`)
  }
  return hash
}
