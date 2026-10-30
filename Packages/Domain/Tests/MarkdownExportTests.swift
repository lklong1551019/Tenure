import Foundation
import Testing

@testable import Domain

@Suite("MarkdownExport")
struct MarkdownExportTests {
    let zalo = Board(name: "Zalo", start: YearMonth(year: 2026, month: 1), createdAt: Timestamp(millis: 0))
    let older = Board(
        name: "Company A",
        start: YearMonth(year: 2017, month: 7),
        end: YearMonth(year: 2019, month: 8),
        createdAt: Timestamp(millis: 0)
    )
    let today = DayDate(year: 2026, month: 10, day: 30)

    var location: Entry {
        var entry = Entry.sample("Location", on: zalo, date: DayDate(year: 2026, month: 10, day: 24))
        entry.endDate = DayDate(year: 2026, month: 10, day: 30)
        entry.link = "https://jira.example.com/browse/ZA-1421"
        entry.tags = ["location"]
        entry.problem = "Access history was **slow**."
        entry.impact = "Users love it."
        entry.metrics = [Metric(label: "Time to execute", before: "18", after: "10", unit: "ms", note: "p50 | 7 days")]
        return entry
    }

    @Test func boardListsTasksOldestFirstWithStoryAndMetrics() {
        let test = Entry.sample("Test", on: zalo, date: DayDate(year: 2026, month: 10, day: 30))
        let text = MarkdownExport.board(zalo, entries: [test, location], exportedOn: today)
        #expect(text.hasPrefix("# Zalo\n\nJan 2026 - now · 2 tasks\n"))
        #expect(text.range(of: "## Location")!.lowerBound < text.range(of: "## Test")!.lowerBound)
        #expect(text.contains("Dev · 24 Oct 2026 - 30 Oct 2026 · <https://jira.example.com/browse/ZA-1421>"))
        #expect(text.contains("Tags: location"))
        #expect(text.contains("**Problem**\n\nAccess history was **slow**."))
        #expect(!text.contains("**Why**"))
        #expect(text.contains("| Time to execute | 18 ms | 10 ms | -44% | p50 \\| 7 days |"))
        #expect(text.hasSuffix("\n"))
    }

    @Test func optionsLeaveOutParts() {
        let options = MarkdownOptions(story: false, metrics: false, linksAndTags: false)
        let text = MarkdownExport.entry(location, options: options)
        #expect(text == "# Location\n\nDev · 24 Oct 2026 - 30 Oct 2026\n")
    }

    @Test func yearGroupsBoardsAndSkipsOtherYears() {
        let old = Entry.sample("Payments", on: older, date: DayDate(year: 2018, month: 3, day: 1))
        var spanning = Entry.sample("Migration", on: older, date: DayDate(year: 2017, month: 12, day: 1))
        spanning.endDate = DayDate(year: 2018, month: 2, day: 1)
        let entries = [location, old, spanning]

        let text = MarkdownExport.year(2018, boards: [zalo, older], entries: entries, exportedOn: today)
        #expect(text.contains("# 2018\n\nExported from Tenure on 30 Oct 2026. 2 tasks from 1 board."))
        #expect(text.contains("## Company A\n\nJul 2017 - Aug 2019"))
        #expect(text.contains("### Migration"))
        #expect(!text.contains("Location"))

        let one = MarkdownExport.year(
            2026,
            boards: [zalo, older],
            entries: entries,
            boardId: older.id,
            exportedOn: today
        )
        #expect(one.contains("0 tasks from 0 boards"))
        #expect(MarkdownExport.years(of: entries) == [2026, 2018, 2017])
    }

    @Test func allListsEveryBoardNewestFirst() {
        let old = Entry.sample("Payments", on: older, date: DayDate(year: 2018, month: 3, day: 1))
        let text = MarkdownExport.all(boards: [older, zalo], entries: [old, location], exportedOn: today)
        #expect(text.hasPrefix("# Tenure\n\nExported from Tenure on 30 Oct 2026. 2 tasks from 2 boards."))
        #expect(text.range(of: "## Zalo")!.lowerBound < text.range(of: "## Company A")!.lowerBound)
        #expect(text.contains("### Payments"))
    }

    @Test func deletedItemsStayOut() {
        var gone = location
        gone.deletedAt = Timestamp(millis: 1)
        #expect(!MarkdownExport.board(zalo, entries: [gone], exportedOn: today).contains("Location"))
        #expect(MarkdownExport.years(of: [gone]).isEmpty)
    }

    @Test func metricChange() {
        #expect(Metric(label: "", before: "18", after: "10").changeText == "-44%")
        #expect(Metric(label: "", before: "1,000", after: "1,005").changeText == "+0.5%")
        #expect(Metric(label: "", before: "4", after: "4").changeText == "0%")
        #expect(Metric(label: "", before: "0", after: "3").changeText == nil)
        #expect(Metric(label: "", before: "fast", after: "faster").changeText == nil)
        #expect(Metric(label: "", after: "10").changeText == nil)
    }

    @Test func fileNameIsSafe() {
        #expect(MarkdownExport.fileName("Zalo / VNG: 2026") == "Zalo - VNG- 2026")
        #expect(MarkdownExport.fileName("  ") == "Tenure")
    }
}
