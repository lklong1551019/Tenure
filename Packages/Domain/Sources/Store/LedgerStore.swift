import Foundation

/// The live ledger. Every change is stamped, written to disk, and only then applied in
/// memory, so a failed write leaves both as they were. Observers get the new snapshot after
/// each change, local or merged from another Mac.
public actor LedgerStore {
    private let repository: any LedgerRepository
    private let clock: any ClockPort
    private var current: LedgerSnapshot
    private var observers: [UUID: AsyncStream<LedgerSnapshot>.Continuation] = [:]

    /// Opens what is on disk, or an empty ledger on first launch. Throws `LedgerError`.
    public init(repository: any LedgerRepository, clock: any ClockPort = SystemClock()) throws {
        self.repository = repository
        self.clock = clock
        self.current = try repository.load() ?? .empty
    }

    public func snapshot() -> LedgerSnapshot {
        current
    }

    /// Creates or updates a board. Returns it as stored.
    @discardableResult
    public func save(_ board: Board) throws -> Board {
        var next = current
        var stamped = board
        stamped.updatedAt = stamp(after: current.boards.first { $0.id == board.id }?.updatedAt)
        stamped.deletedAt = nil
        upsert(stamped, into: &next.boards)
        try commit(next)
        return stamped
    }

    /// Deletes a board and every entry on it.
    public func deleteBoard(_ id: UUID) throws {
        guard let board = current.boards.first(where: { $0.id == id && !$0.isDeleted }) else {
            throw LedgerError.notFound
        }
        var next = current
        let now = stamp(after: board.updatedAt)
        upsert(tombstone(board, at: now), into: &next.boards)
        for entry in current.entries where entry.boardId == id && !entry.isDeleted {
            upsert(tombstone(entry, at: stamp(after: entry.updatedAt)), into: &next.entries)
        }
        try commit(next)
    }

    /// Creates or updates an entry on a live board. Returns it as stored.
    @discardableResult
    public func save(_ entry: Entry) throws -> Entry {
        guard current.boards.contains(where: { $0.id == entry.boardId && !$0.isDeleted }) else {
            throw LedgerError.notFound
        }
        var next = current
        var stamped = entry
        stamped.updatedAt = stamp(after: current.entries.first { $0.id == entry.id }?.updatedAt)
        stamped.deletedAt = nil
        upsert(stamped, into: &next.entries)
        try commit(next)
        return stamped
    }

    /// Adds or updates several entries in one write, as an import does: all or nothing.
    /// Throws `notFound` if any is on a board that is missing or deleted.
    @discardableResult
    public func save(_ entries: [Entry]) throws -> [Entry] {
        let liveBoards = Set(current.boards.filter { !$0.isDeleted }.map(\.id))
        guard entries.allSatisfy({ liveBoards.contains($0.boardId) }) else { throw LedgerError.notFound }
        guard !entries.isEmpty else { return [] }
        var next = current
        var previous: Timestamp?
        let stamped = entries.map { entry in
            var stamped = entry
            // Each after the last, so the import keeps its order in time.
            let existing = current.entries.first { $0.id == entry.id }?.updatedAt
            stamped.updatedAt = stamp(after: [previous, existing].compactMap { $0 }.max())
            stamped.deletedAt = nil
            previous = stamped.updatedAt
            return stamped
        }
        for entry in stamped {
            upsert(entry, into: &next.entries)
        }
        try commit(next)
        return stamped
    }

    public func deleteEntry(_ id: UUID) throws {
        guard let entry = current.entries.first(where: { $0.id == id && !$0.isDeleted }) else {
            throw LedgerError.notFound
        }
        var next = current
        upsert(tombstone(entry, at: stamp(after: entry.updatedAt)), into: &next.entries)
        try commit(next)
    }

    /// Merges another copy in (from Drive, or an imported file). Returns whether anything
    /// changed; nothing is written when nothing did.
    @discardableResult
    public func merge(_ other: LedgerSnapshot) throws -> Bool {
        let merged = MergePolicy.merge(local: current, remote: other, now: clock.now())
        guard SnapshotFingerprint.of(merged) != SnapshotFingerprint.of(current) else { return false }
        try commit(merged)
        return true
    }

    /// Yields the current snapshot first, then every change. Only the newest waits for a slow
    /// reader: each snapshot replaces the last, so older ones are never worth queuing.
    public func changes() -> AsyncStream<LedgerSnapshot> {
        let (stream, continuation) = AsyncStream<LedgerSnapshot>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        observers[id] = continuation
        continuation.yield(current)
        continuation.onTermination = { _ in Task { await self.removeObserver(id) } }
        return stream
    }

    // MARK: Private

    /// Now, but always after the item's previous stamp: an edit must win over the version it
    /// replaces even when this Mac's clock runs behind the one that wrote it.
    private func stamp(after previous: Timestamp?) -> Timestamp {
        let now = clock.now()
        guard let previous, now <= previous else { return now }
        return previous.adding(millis: 1)
    }

    private func tombstone<Item: LedgerItem>(_ item: Item, at time: Timestamp) -> Item {
        var deleted = item
        deleted.updatedAt = time
        deleted.deletedAt = time
        return deleted
    }

    private func upsert<Item: LedgerItem>(_ item: Item, into items: inout [Item]) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
    }

    private func commit(_ next: LedgerSnapshot) throws {
        do {
            try repository.save(next)
        } catch {
            throw LedgerError.saveFailed
        }
        current = next
        for continuation in observers.values {
            continuation.yield(next)
        }
    }

    private func removeObserver(_ id: UUID) {
        observers[id] = nil
    }
}
