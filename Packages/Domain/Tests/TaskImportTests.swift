import Foundation
import Testing

@testable import Domain

@Suite("TaskImport")
struct TaskImportTests {
    let board = Board.sample("Zalo", start: YearMonth(year: 2024, month: 1))

    @Test func readsTabSeparatedRowsWithLinksNotesAndDates() {
        let text = """
            Name\tLink\tDate\tEnd
            Zalo - remote config : support config with file\thttps://jira.example.com/browse/ZPLA-4684\t2025-01-15
            Benchmark hilt\thttps://zdoc.example.com/Hilt+Benchmark\t03/02/2025\t10/02/2025
            Update Qos: write benchmarking code\t\t20.02.2025
            Review fresher course\tFound many mistakes in the content\t2025/03/01
            """
        let rows = TaskImport.review(text, boardId: board.id, existing: [])
        #expect(rows.map(\.status) == [.ready, .ready, .ready, .ready])
        #expect(rows[0].link == "https://jira.example.com/browse/ZPLA-4684")
        #expect(rows[1].date == DayDate(year: 2025, month: 2, day: 3))
        #expect(rows[1].endDate == DayDate(year: 2025, month: 2, day: 10))
        #expect(rows[2].link == nil)
        #expect(rows[2].note == nil)
        #expect(rows[3].note == "Found many mistakes in the content")
        #expect(rows[3].link == nil)
    }

    @Test func quotedCellsSpanLinesAndKeepQuotes() {
        let text =
            "\"Improve Qos: progress,\nparallel upload\"\thttps://x.example.com/1\t2025-04-01\n"
            + "\"Say \"\"hi\"\"\"\t\t2025-04-02\n"
        let rows = TaskImport.review(text, boardId: board.id, existing: [])
        #expect(rows.map(\.name) == ["Improve Qos: progress, parallel upload", "Say \"hi\""])
        #expect(rows.allSatisfy { $0.isReady })
    }

    @Test func readsCSVWhenThereAreNoTabs() {
        let rows = TaskImport.review(
            "\"Fix crash, again\",https://x.example.com/2,2025-05-06",
            boardId: board.id,
            existing: []
        )
        #expect(rows.first?.name == "Fix crash, again")
        #expect(rows.first?.isReady == true)
    }

    @Test func flagsRowsThatCannotBeImported() {
        var existing = Entry.sample("Benchmark hilt", on: board)
        existing.link = "https://zdoc.example.com/Hilt"
        let text = """
            No date\thttps://x.example.com/3
            Bad date\t\t31/02/2025
            Backwards\t\t2025-03-10\t2025-03-01
            \thttps://x.example.com/4\t2025-01-01
            Benchmark hilt\thttps://zdoc.example.com/Hilt\t2025-01-01
            Twice\t\t2025-01-01
            twice\t\t2025-01-02
            """
        let rows = TaskImport.review(text, boardId: board.id, existing: [existing])
        #expect(
            rows.map(\.status) == [
                .missingDate, .unreadableDate("31/02/2025"), .endBeforeStart, .missingName, .duplicate, .ready,
                .duplicate,
            ]
        )
    }

    @Test func buildsTasksFromReadyRowsOnly() {
        let rows = TaskImport.review(
            "Done\thttps://x.example.com/5\t2025-06-01\t2025-06-01\nLater\tWhy it mattered\t\n",
            boardId: board.id,
            existing: []
        )
        let entries = TaskImport.entries(from: rows, boardId: board.id, type: .dev, createdAt: Timestamp(millis: 5))
        #expect(entries.count == 1)
        #expect(entries[0].name == "Done")
        #expect(entries[0].type == .dev)
        #expect(entries[0].endDate == nil)
        #expect(entries[0].link == "https://x.example.com/5")
    }

    @Test func parsesDates() {
        #expect(TaskImport.parseDate("2025-03-12") == DayDate(year: 2025, month: 3, day: 12))
        #expect(TaskImport.parseDate("12/03/2025") == DayDate(year: 2025, month: 3, day: 12))
        #expect(TaskImport.parseDate("1/3/2025") == DayDate(year: 2025, month: 3, day: 1))
        #expect(TaskImport.parseDate("29/02/2025") == nil)
        #expect(TaskImport.parseDate("March 3") == nil)
        #expect(TaskImport.parseDate("") == nil)
    }
}
