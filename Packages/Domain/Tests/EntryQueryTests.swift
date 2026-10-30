import Foundation
import Testing

@testable import Domain

@Suite("EntryQuery")
struct EntryQueryTests {
    let a = Board.sample("A")
    let b = Board.sample("B")

    var entries: [Entry] {
        [
            .sample("Cold start", on: a, date: DayDate(year: 2026, month: 3, day: 12), type: .dev),
            .sample("Crash on rotate", on: a, date: DayDate(year: 2025, month: 11, day: 2), type: .bugFix),
            .sample("Onboarding", on: b, date: DayDate(year: 2025, month: 6, day: 20), type: .product),
            .sample("Áudit leak", on: b, date: DayDate(year: 2024, month: 9, day: 15), type: .findings),
        ]
    }

    @Test func sortsByDateAndName() {
        #expect(
            EntryQuery(sort: .newest).apply(to: entries).map(\.name)
                == ["Cold start", "Crash on rotate", "Onboarding", "Áudit leak"]
        )
        #expect(EntryQuery(sort: .oldest).apply(to: entries).first?.name == "Áudit leak")
        #expect(
            EntryQuery(sort: .nameAscending).apply(to: entries).map(\.name)
                == ["Áudit leak", "Cold start", "Crash on rotate", "Onboarding"]
        )
        #expect(EntryQuery(sort: .nameDescending).apply(to: entries).first?.name == "Onboarding")
    }

    @Test func filtersByBoardTypeAndText() {
        #expect(EntryQuery(boardId: b.id).apply(to: entries).count == 2)
        #expect(
            EntryQuery(types: [.bugFix, .product]).apply(to: entries).map(\.name) == ["Crash on rotate", "Onboarding"]
        )
        #expect(EntryQuery(text: "audit").apply(to: entries).map(\.name) == ["Áudit leak"])
        #expect(EntryQuery(boardId: a.id, text: "onboarding").apply(to: entries).isEmpty)
    }

    @Test func searchRanksNamePrefixFirst() {
        let ranked = EntrySearch.search("c", in: entries).map(\.name)
        #expect(ranked.prefix(2) == ["Cold start", "Crash on rotate"])
    }
}
