import Foundation

@testable import Domain

final class InMemoryRepository: LedgerRepository, @unchecked Sendable {
    // Invariant for @unchecked Sendable: every access goes through `lock`.
    private let lock = NSLock()
    private var stored: LedgerSnapshot?
    private var failSaves = false

    init(_ snapshot: LedgerSnapshot? = nil) {
        stored = snapshot
    }

    var snapshot: LedgerSnapshot? { lock.withLock { stored } }

    func failNextSaves(_ fail: Bool) {
        lock.withLock { failSaves = fail }
    }

    func load() throws -> LedgerSnapshot? { lock.withLock { stored } }

    func save(_ snapshot: LedgerSnapshot) throws {
        try lock.withLock {
            if failSaves { throw LedgerError.saveFailed }
            stored = snapshot
        }
    }
}

final class MutableClock: ClockPort, @unchecked Sendable {
    // Invariant for @unchecked Sendable: every access goes through `lock`.
    private let lock = NSLock()
    private var value: Timestamp

    init(_ value: Timestamp = Timestamp(millis: 1_790_000_000_000)) {
        self.value = value
    }

    func now() -> Timestamp { lock.withLock { value } }

    func set(_ newValue: Timestamp) {
        lock.withLock { value = newValue }
    }

    func advance(millis: Int64 = 1000) {
        lock.withLock { value = value.adding(millis: millis) }
    }
}

/// Plain JSON, like the real codec without the envelope.
struct JSONCodec: LedgerCodecPort {
    func encode(_ snapshot: LedgerSnapshot) throws -> Data {
        try JSONEncoder().encode(snapshot)
    }

    func decode(_ data: Data) throws -> LedgerSnapshot {
        do {
            return try JSONDecoder().decode(LedgerSnapshot.self, from: data)
        } catch {
            throw LedgerError.corruptFile
        }
    }
}

/// Cloud storage in memory: an append-only revision list, like Drive's history.
actor FakeRemoteStore: RemoteStorePort {
    private(set) var revisions: [(revision: RemoteRevision, data: Data, pinned: Bool)] = []
    private var nextError: RemoteStoreError?
    /// Runs inside `upload`, before the upload lands: another Mac's upload in between.
    private var beforeNextUpload: (@Sendable () async -> Void)?

    var uploadCount: Int { revisions.count }
    var pinnedCount: Int { revisions.filter(\.pinned).count }
    var headData: Data? { revisions.last?.data }

    func failNext(_ error: RemoteStoreError) {
        nextError = error
    }

    func interleave(_ action: @escaping @Sendable () async -> Void) {
        beforeNextUpload = action
    }

    /// Writes as an outside party would: no merge, no checks.
    @discardableResult
    func put(_ data: Data) -> RemoteRevision {
        let revision = RemoteRevision("rev-\(revisions.count + 1)")
        revisions.append((revision, data, false))
        return revision
    }

    func head() async throws -> RemoteRevision? {
        try takeError()
        return revisions.last?.revision
    }

    func download(_ revision: RemoteRevision) async throws -> Data {
        try takeError()
        guard let entry = revisions.first(where: { $0.revision == revision }) else { throw RemoteStoreError.notFound }
        return entry.data
    }

    func upload(_ data: Data, pin: Bool) async throws -> RemoteRevision {
        try takeError()
        if let action = beforeNextUpload {
            beforeNextUpload = nil
            await action()
        }
        let revision = RemoteRevision("rev-\(revisions.count + 1)")
        revisions.append((revision, data, pin))
        return revision
    }

    func revisions(after revision: RemoteRevision) async throws -> [RemoteRevision] {
        try takeError()
        guard let index = revisions.firstIndex(where: { $0.revision == revision }) else { return [] }
        return revisions[(index + 1)...].map(\.revision)
    }

    private func takeError() throws {
        if let error = nextError {
            nextError = nil
            throw error
        }
    }
}

final class InMemorySyncState: SyncStatePort, @unchecked Sendable {
    // Invariant for @unchecked Sendable: every access goes through `lock`.
    private let lock = NSLock()
    private var stored: SyncRecord?

    func record() -> SyncRecord? { lock.withLock { stored } }
    func save(_ record: SyncRecord) { lock.withLock { stored = record } }
    func clear() { lock.withLock { stored = nil } }
}

extension Board {
    static func sample(_ name: String = "Company A", start: YearMonth = YearMonth(year: 2017, month: 7)) -> Board {
        Board(name: name, start: start, createdAt: Timestamp(millis: 0))
    }
}

extension Entry {
    static func sample(
        _ name: String,
        on board: Board,
        date: DayDate = DayDate(year: 2018, month: 1, day: 1),
        type: EntryType = .dev
    ) -> Entry {
        Entry(boardId: board.id, name: name, type: type, date: date, createdAt: Timestamp(millis: 0))
    }
}
