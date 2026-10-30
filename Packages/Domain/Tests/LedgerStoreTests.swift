import Foundation
import Testing

@testable import Domain

@Suite("LedgerStore")
struct LedgerStoreTests {
    let repository = InMemoryRepository()
    let clock = MutableClock()

    @Test func savesStampAndPersist() async throws {
        let store = try LedgerStore(repository: repository, clock: clock)
        let board = try await store.save(Board.sample())
        #expect(board.updatedAt == clock.now())
        let entry = try await store.save(Entry.sample("Cold start", on: board))
        #expect(repository.snapshot?.entries.map(\.name) == ["Cold start"])
        #expect(entry.updatedAt == clock.now())
    }

    @Test func editAlwaysMovesTheStampForward() async throws {
        let store = try LedgerStore(repository: repository, clock: clock)
        let board = try await store.save(Board.sample())
        // Clock runs behind the stored stamp, as after a merge from a Mac ahead in time.
        clock.set(board.updatedAt.adding(millis: -5000))
        let again = try await store.save(board)
        #expect(again.updatedAt > board.updatedAt)
    }

    @Test func deletingBoardTombstonesItsEntries() async throws {
        let store = try LedgerStore(repository: repository, clock: clock)
        let board = try await store.save(Board.sample())
        try await store.save(Entry.sample("a", on: board))
        clock.advance()
        try await store.deleteBoard(board.id)
        let snapshot = await store.snapshot()
        #expect(snapshot.liveBoards.isEmpty)
        #expect(snapshot.entries.allSatisfy { $0.isDeleted })
    }

    @Test func entryNeedsALiveBoard() async throws {
        let store = try LedgerStore(repository: repository, clock: clock)
        await #expect(throws: LedgerError.notFound) {
            try await store.save(Entry.sample("orphan", on: .sample()))
        }
    }

    @Test func failedSaveChangesNothing() async throws {
        let store = try LedgerStore(repository: repository, clock: clock)
        let board = try await store.save(Board.sample())
        repository.failNextSaves(true)
        await #expect(throws: LedgerError.saveFailed) {
            try await store.save(Entry.sample("lost", on: board))
        }
        #expect(await store.snapshot().entries.isEmpty)
    }

    @Test func mergeReportsWhetherAnythingChanged() async throws {
        let store = try LedgerStore(repository: repository, clock: clock)
        let board = try await store.save(Board.sample())
        let same = await store.snapshot()
        #expect(try await store.merge(same) == false)
        var other = same
        other.entries.append(Entry.sample("from other Mac", on: board))
        #expect(try await store.merge(other) == true)
        #expect(repository.snapshot?.entries.count == 1)
    }

    @Test func observersSeeEveryChange() async throws {
        let store = try LedgerStore(repository: repository, clock: clock)
        var iterator = await store.changes().makeAsyncIterator()
        #expect(await iterator.next()?.boards.isEmpty == true)
        try await store.save(Board.sample())
        #expect(await iterator.next()?.boards.count == 1)
    }
}
