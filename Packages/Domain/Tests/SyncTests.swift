import Foundation
import Testing

@testable import Domain

/// Two Macs sharing one remote copy, as through Google Drive.
struct SyncBed {
    let remote = FakeRemoteStore()
    let codec = JSONCodec()
    let clock = MutableClock()

    struct Mac {
        let repository: InMemoryRepository
        let store: LedgerStore
        let state = InMemorySyncState()
    }

    func mac() throws -> Mac {
        let repository = InMemoryRepository()
        return Mac(repository: repository, store: try LedgerStore(repository: repository, clock: clock))
    }

    func sync(_ mac: Mac) -> SyncLedger {
        SyncLedger(remote: remote, codec: codec, state: mac.state, clock: clock)
    }

    func names(on mac: Mac) async -> Set<String> {
        Set(await mac.store.snapshot().liveEntries.map(\.name))
    }
}

@Suite("SyncLedger")
struct SyncTests {
    let bed = SyncBed()

    @Test func firstRoundCreatesAPinnedRemote() async throws {
        let mac = try bed.mac()
        try await mac.store.save(Board.sample())
        #expect(try await bed.sync(mac)(mac.store) == .pushed)
        #expect(await bed.remote.uploadCount == 1)
        #expect(await bed.remote.pinnedCount == 1)
        #expect(try await bed.sync(mac)(mac.store) == .upToDate)
        #expect(await bed.remote.uploadCount == 1)
    }

    @Test func twoMacsConverge() async throws {
        let one = try bed.mac()
        let board = try await one.store.save(Board.sample())
        try await bed.sync(one)(one.store)
        let two = try bed.mac()
        #expect(try await bed.sync(two)(two.store) == .pulled)

        bed.clock.advance()
        try await one.store.save(Entry.sample("from one", on: board))
        bed.clock.advance()
        try await two.store.save(Entry.sample("from two", on: board))
        try await bed.sync(one)(one.store)
        try await bed.sync(two)(two.store)
        try await bed.sync(one)(one.store)
        #expect(await bed.names(on: one) == ["from one", "from two"])
        #expect(await bed.names(on: two) == ["from one", "from two"])
    }

    @Test func deleteReachesTheOtherMac() async throws {
        let one = try bed.mac()
        let board = try await one.store.save(Board.sample())
        let entry = try await one.store.save(Entry.sample("gone", on: board))
        try await bed.sync(one)(one.store)
        let two = try bed.mac()
        try await bed.sync(two)(two.store)
        bed.clock.advance()
        try await two.store.deleteEntry(entry.id)
        try await bed.sync(two)(two.store)
        try await bed.sync(one)(one.store)
        #expect(await bed.names(on: one).isEmpty)
    }

    @Test func uploadThatLandedInBetweenIsMergedAgain() async throws {
        let one = try bed.mac()
        let board = try await one.store.save(Board.sample())
        try await bed.sync(one)(one.store)
        let two = try bed.mac()
        try await bed.sync(two)(two.store)

        bed.clock.advance()
        try await two.store.save(Entry.sample("sneaky", on: board))
        bed.clock.advance()
        try await one.store.save(Entry.sample("mine", on: board))
        let syncTwo = bed.sync(two)
        await bed.remote.interleave { _ = try? await syncTwo(two.store) }
        #expect(try await bed.sync(one)(one.store) == .pushed)
        #expect(await bed.names(on: one) == ["sneaky", "mine"])
        let final = try bed.codec.decode(try #require(await bed.remote.headData))
        #expect(Set(final.entries.map(\.name)) == ["sneaky", "mine"])
    }

    @Test func refusesNewerFormatAndFutureStamps() async throws {
        let mac = try bed.mac()
        try await mac.store.save(Board.sample())
        await bed.remote.put(Data("garbage".utf8))
        await #expect(throws: SyncError.corruptRemote) { try await bed.sync(mac)(mac.store) }

        var future = Board.sample("future")
        future.updatedAt = bed.clock.now().adding(days: 2)
        await bed.remote.put(try bed.codec.encode(LedgerSnapshot(boards: [future])))
        await #expect(throws: SyncError.corruptRemote) { try await bed.sync(mac)(mac.store) }
        #expect(await mac.store.snapshot().boards.count == 1)
    }

    @Test func transportAndDiskErrorsAreMapped() async throws {
        let mac = try bed.mac()
        try await mac.store.save(Board.sample())
        await bed.remote.failNext(.offline)
        await #expect(throws: SyncError.remote(.offline)) { try await bed.sync(mac)(mac.store) }

        let other = try bed.mac()
        try await other.store.save(Board.sample("other"))
        try await bed.sync(other)(other.store)
        mac.repository.failNextSaves(true)
        await #expect(throws: SyncError.localWriteFailed) { try await bed.sync(mac)(mac.store) }
    }
}
