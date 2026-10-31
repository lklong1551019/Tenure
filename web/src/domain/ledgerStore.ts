// Port of Packages/Domain/Sources/Store/LedgerStore.swift. The live ledger: every change is
// stamped and then published to subscribers. The web keeps no local file (Drive is the only
// copy it writes), so "write, then apply" reduces to building the next snapshot first and
// swapping it in whole: a change that throws leaves the ledger as it was.
import { LedgerError } from './errors'
import { fingerprint } from './fingerprint'
import { merge } from './merge'
import type { Board, Entry, LedgerItem, LedgerSnapshot, Uuid } from './model'
import { emptySnapshot, isDeleted } from './model'
import { type ClockPort, systemClock } from './ports'
import { addMillis, type Timestamp } from './timestamp'

export class LedgerStore {
  private current: LedgerSnapshot
  private readonly listeners = new Set<() => void>()

  constructor(
    initial: LedgerSnapshot = emptySnapshot,
    private readonly clock: ClockPort = systemClock,
  ) {
    this.current = initial
  }

  snapshot(): LedgerSnapshot {
    return this.current
  }

  /** For `useSyncExternalStore`: called after every change, local or merged. */
  subscribe(listener: () => void): () => void {
    this.listeners.add(listener)
    return () => this.listeners.delete(listener)
  }

  /** Creates or updates a board. Returns it as stored. */
  saveBoard(board: Board): Board {
    const previous = this.current.boards.find((item) => item.id === board.id)
    const stamped = live({ ...board, updatedAt: this.stamp(previous?.updatedAt) })
    this.commit({ ...this.current, boards: upsert(this.current.boards, stamped) })
    return stamped
  }

  /** Deletes a board and every entry on it. */
  deleteBoard(id: Uuid): void {
    const board = this.current.boards.find((item) => item.id === id && !isDeleted(item))
    if (!board) throw new LedgerError({ kind: 'notFound' })
    let entries = this.current.entries
    for (const entry of this.current.entries) {
      if (entry.boardId === id && !isDeleted(entry)) {
        entries = upsert(entries, tombstone(entry, this.stamp(entry.updatedAt)))
      }
    }
    const boards = upsert(this.current.boards, tombstone(board, this.stamp(board.updatedAt)))
    this.commit({ boards, entries })
  }

  /** Creates or updates an entry on a live board. Returns it as stored. */
  saveEntry(entry: Entry): Entry {
    if (!this.current.boards.some((board) => board.id === entry.boardId && !isDeleted(board))) {
      throw new LedgerError({ kind: 'notFound' })
    }
    const previous = this.current.entries.find((item) => item.id === entry.id)
    const stamped = live({ ...entry, updatedAt: this.stamp(previous?.updatedAt) })
    this.commit({ ...this.current, entries: upsert(this.current.entries, stamped) })
    return stamped
  }

  deleteEntry(id: Uuid): void {
    const entry = this.current.entries.find((item) => item.id === id && !isDeleted(item))
    if (!entry) throw new LedgerError({ kind: 'notFound' })
    const entries = upsert(this.current.entries, tombstone(entry, this.stamp(entry.updatedAt)))
    this.commit({ ...this.current, entries })
  }

  /** Merges another copy in. Returns whether anything changed. */
  merge(other: LedgerSnapshot): boolean {
    const merged = merge(this.current, other, this.clock.now())
    if (fingerprint(merged) === fingerprint(this.current)) return false
    this.commit(merged)
    return true
  }

  /** Forgets everything, on sign-out: the next account starts from its own file. */
  reset(): void {
    this.commit(emptySnapshot)
  }

  /**
   * Now, but always after the item's previous stamp: an edit must win over the version it
   * replaces even when this device's clock runs behind the one that wrote it.
   */
  private stamp(previous: Timestamp | undefined): Timestamp {
    const now = this.clock.now()
    if (previous === undefined || now > previous) return now
    return addMillis(previous, 1)
  }

  private commit(next: LedgerSnapshot): void {
    this.current = next
    for (const listener of this.listeners) listener()
  }
}

function live<Item extends LedgerItem>(item: Item): Item {
  const { deletedAt, ...rest } = item
  return rest as Item
}

function tombstone<Item extends LedgerItem>(item: Item, time: Timestamp): Item {
  return { ...item, updatedAt: time, deletedAt: time }
}

function upsert<Item extends LedgerItem>(items: readonly Item[], item: Item): Item[] {
  const index = items.findIndex((existing) => existing.id === item.id)
  if (index === -1) return [...items, item]
  return items.map((existing, position) => (position === index ? item : existing))
}
