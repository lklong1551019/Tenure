import Foundation
import Testing

@testable import Domain

@Suite("Model")
struct ModelTests {
    @Test func calendarDatesRoundTripAsText() throws {
        let board = Board(
            name: "A",
            start: YearMonth(year: 2017, month: 7),
            end: YearMonth(year: 2019, month: 8),
            createdAt: Timestamp(millis: 5)
        )
        let json = String(decoding: try JSONEncoder().encode(board), as: UTF8.self)
        #expect(json.contains("\"2017-07\""))
        #expect(json.contains("\"2019-08\""))
        #expect(try JSONDecoder().decode(Board.self, from: Data(json.utf8)) == board)
        #expect(DayDate(string: "2026-03-12") == DayDate(year: 2026, month: 3, day: 12))
        #expect(DayDate(string: "2026-13-01") == nil)
        #expect(YearMonth(string: "2017-7") == YearMonth(year: 2017, month: 7))
    }

    @Test func unknownTypeSurvivesRoundTrip() throws {
        let json = """
            {"id":"\(UUID().uuidString)","boardId":"\(UUID().uuidString)","updatedAt":10,
             "name":"X","type":"research"}
            """
        let entry = try JSONDecoder().decode(Entry.self, from: Data(json.utf8))
        #expect(entry.type == EntryType(rawValue: "research"))
        let again = try JSONDecoder().decode(Entry.self, from: try JSONEncoder().encode(entry))
        #expect(again.type.rawValue == "research")
    }

    @Test func malformedFieldsFallBackInsteadOfFailing() throws {
        let json = """
            {"id":"\(UUID().uuidString)","boardId":"\(UUID().uuidString)","updatedAt":10,
             "name":42,"date":"not a date","tags":"oops","metrics":[{"label":"p50","after":"1s"}],
             "futureField":{"nested":true}}
            """
        let entry = try JSONDecoder().decode(Entry.self, from: Data(json.utf8))
        #expect(entry.name == "")
        #expect(entry.tags == [])
        #expect(entry.metrics.map(\.label) == ["p50"])
        #expect(entry.createdAt == Timestamp(millis: 10))
    }

    @Test func liveEntriesHideEntriesOfDeletedBoards() {
        var gone = Board.sample("Gone")
        gone.deletedAt = Timestamp(millis: 1)
        let kept = Board.sample("Kept")
        let snapshot = LedgerSnapshot(
            boards: [gone, kept],
            entries: [.sample("a", on: gone), .sample("b", on: kept)]
        )
        #expect(snapshot.liveBoards.map(\.name) == ["Kept"])
        #expect(snapshot.liveEntries.map(\.name) == ["b"])
    }

    @Test func outOfRangeYearsReadAsInvalid() {
        #expect(DayDate(string: "20250-01-01") == nil)
        #expect(DayDate(string: "0-01-01") == nil)
        #expect(YearMonth(string: "99999-12") == nil)
        #expect(DayDate(year: 1_000_000, month: 1, day: 1).year == 9999)
        #expect(DayDate(string: "2026-03-12")?.year == 2026)
    }
}
