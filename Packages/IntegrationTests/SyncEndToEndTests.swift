import Domain
import Foundation
import Persistence
import Testing

/// Cloud storage in memory: an append-only revision list, like Drive's history.
actor MemoryRemote: RemoteStorePort {
    private var revisions: [(revision: RemoteRevision, data: Data)] = []

    var headData: Data? { revisions.last?.data }

    func head() async throws -> RemoteRevision? { revisions.last?.revision }

    func download(_ revision: RemoteRevision) async throws -> Data {
        guard let entry = revisions.first(where: { $0.revision == revision }) else { throw RemoteStoreError.notFound }
        return entry.data
    }

    func upload(_ data: Data, pin: Bool) async throws -> RemoteRevision {
        let revision = RemoteRevision("rev-\(revisions.count + 1)")
        revisions.append((revision, data))
        return revision
    }

    func revisions(after revision: RemoteRevision) async throws -> [RemoteRevision] {
        guard let index = revisions.firstIndex(where: { $0.revision == revision }) else { return [] }
        return revisions[(index + 1)...].map(\.revision)
    }
}

final class MemoryState: SyncStatePort, @unchecked Sendable {
    // Invariant for @unchecked Sendable: every access goes through `lock`.
    private let lock = NSLock()
    private var stored: SyncRecord?

    func record() -> SyncRecord? { lock.withLock { stored } }
    func save(_ record: SyncRecord) { lock.withLock { stored = record } }
    func clear() { lock.withLock { stored = nil } }
}

/// Two Macs, each with a real `tenure.json` on disk, syncing through one remote copy.
@Suite("Sync end to end")
struct SyncEndToEndTests {
    @Test func twoMacsConvergeThroughRealFiles() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "tenure-it-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let remote = MemoryRemote()
        let codec = LedgerFileCodec()

        func mac(_ name: String) throws -> (FileLedgerRepository, LedgerStore, SyncLedger) {
            let repository = FileLedgerRepository(fileURL: directory.appending(path: "\(name)/tenure.json"))
            let store = try LedgerStore(repository: repository)
            return (repository, store, SyncLedger(remote: remote, codec: codec, state: MemoryState()))
        }

        let (_, storeOne, syncOne) = try mac("one")
        let board = try await storeOne.save(
            Board(name: "Company A", start: YearMonth(year: 2017, month: 7), createdAt: Timestamp(Date()))
        )
        try await storeOne.save(
            Entry(
                boardId: board.id,
                name: "CI pipeline",
                date: DayDate(year: 2018, month: 5, day: 10),
                createdAt: Timestamp(Date())
            )
        )
        #expect(try await syncOne(storeOne) == .pushed)

        let (repositoryTwo, storeTwo, syncTwo) = try mac("two")
        #expect(try await syncTwo(storeTwo) == .pulled)
        #expect(try repositoryTwo.load()?.liveEntries.map(\.name) == ["CI pipeline"])

        try await Task.sleep(for: .milliseconds(5))
        try await storeTwo.save(
            Entry(
                boardId: board.id,
                name: "Crash fix",
                date: DayDate(year: 2019, month: 1, day: 3),
                createdAt: Timestamp(Date())
            )
        )
        try await syncTwo(storeTwo)
        try await syncOne(storeOne)
        #expect(Set(await storeOne.snapshot().liveEntries.map(\.name)) == ["CI pipeline", "Crash fix"])

        let text = String(decoding: try #require(await remote.headData), as: UTF8.self)
        #expect(text.contains("\"name\" : \"Crash fix\""))
    }
}
