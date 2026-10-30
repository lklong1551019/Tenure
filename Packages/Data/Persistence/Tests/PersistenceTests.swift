import Domain
import Foundation
import Testing

@testable import Persistence

private func sampleSnapshot() -> LedgerSnapshot {
    let board = Board(
        name: "Company A",
        start: YearMonth(year: 2017, month: 7),
        end: YearMonth(year: 2019, month: 8),
        createdAt: Timestamp(millis: 10)
    )
    let entry = Entry(
        boardId: board.id,
        name: "CI pipeline",
        link: "https://example.com/TCK-1",
        type: .dev,
        date: DayDate(year: 2018, month: 5, day: 10),
        tags: ["ci"],
        problem: "Manual builds",
        metrics: [Metric(label: "Release time", before: "40m", after: "8m", note: "10 runs")],
        createdAt: Timestamp(millis: 20)
    )
    return LedgerSnapshot(boards: [board], entries: [entry])
}

private func withTempDirectory(_ body: (URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "tenure-tests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    try body(directory)
}

@Suite("Ledger file codec")
struct LedgerFileCodecTests {
    let codec = LedgerFileCodec()

    @Test func roundTrip() throws {
        let snapshot = sampleSnapshot()
        #expect(try codec.decode(try codec.encode(snapshot)) == snapshot)
    }

    @Test func fileIsReadableJSON() throws {
        let text = String(decoding: try codec.encode(sampleSnapshot()), as: UTF8.self)
        #expect(text.contains("\"format\" : \"tenure\""))
        #expect(text.contains("\"version\" : 1"))
        #expect(text.contains("\"start\" : \"2017-07\""))
        #expect(text.contains("\"date\" : \"2018-05-10\""))
        #expect(text.contains("https://example.com/TCK-1"))
    }

    @Test func refusesNewerVersion() throws {
        let data = Data(#"{"format":"tenure","version":2,"boards":[],"entries":[]}"#.utf8)
        #expect(throws: LedgerError.unsupportedFormatVersion(2)) { try codec.decode(data) }
    }

    @Test func refusesForeignAndBrokenFiles() throws {
        #expect(throws: LedgerError.corruptFile) { try codec.decode(Data("[]".utf8)) }
        #expect(throws: LedgerError.corruptFile) {
            try codec.decode(Data(#"{"format":"other","version":1,"boards":[],"entries":[]}"#.utf8))
        }
        #expect(throws: LedgerError.corruptFile) {
            try codec.decode(Data(#"{"format":"tenure","version":1,"boards":[{}],"entries":[]}"#.utf8))
        }
    }

    @Test func refusesDuplicateIds() throws {
        var snapshot = sampleSnapshot()
        snapshot.entries.append(snapshot.entries[0])
        let data = try codec.encode(snapshot)
        #expect(throws: LedgerError.corruptFile) { try codec.decode(data) }
    }
}

@Suite("File repository")
struct FileLedgerRepositoryTests {
    @Test func missingFileLoadsAsNil() throws {
        try withTempDirectory { directory in
            let repository = FileLedgerRepository(fileURL: directory.appending(path: "tenure.json"))
            let loaded = try repository.load()
            #expect(loaded == nil)
        }
    }

    @Test func saveThenLoadWithOwnerOnlyPermissions() throws {
        try withTempDirectory { directory in
            let url = directory.appending(path: "Tenure/tenure.json")
            let repository = FileLedgerRepository(fileURL: url)
            try repository.save(sampleSnapshot())
            try repository.save(sampleSnapshot())
            let loaded = try repository.load()
            #expect(loaded?.entries.first?.name == "CI pipeline")
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            #expect((attributes[.posixPermissions] as? Int) == 0o600)
            let leftovers = try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path)
            #expect(leftovers == ["tenure.json"])
        }
    }
}

@Suite("Sync state")
struct SyncStateTests {
    @Test func roundTripAndClear() throws {
        let suite = "tenure-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = UserDefaultsSyncState(defaults: defaults)
        #expect(state.record() == nil)
        let record = SyncRecord(
            revision: RemoteRevision("r1"),
            fingerprint: 42,
            syncedAt: Timestamp(millis: 1),
            pinnedDay: 3
        )
        state.save(record)
        #expect(state.record() == record)
        defaults.set(Data("junk".utf8), forKey: UserDefaultsSyncState.key)
        #expect(state.record() == nil)
        state.clear()
        #expect(defaults.data(forKey: UserDefaultsSyncState.key) == nil)
    }
}
