import Foundation
import Testing

@testable import Domain

@Suite("MergePolicy")
struct MergePolicyTests {
    let now = Timestamp(millis: 1_790_000_000_000)

    @Test func newerEditWins() {
        let board = Board.sample()
        var older = Entry.sample("old", on: board)
        older.updatedAt = Timestamp(millis: 100)
        var newer = older
        newer.name = "new"
        newer.updatedAt = Timestamp(millis: 200)
        let merged = MergePolicy.mergeItems(local: [older], remote: [newer], now: now)
        #expect(merged.map(\.name) == ["new"])
        #expect(MergePolicy.mergeItems(local: [newer], remote: [older], now: now).map(\.name) == ["new"])
    }

    @Test func deleteBeatsEditAtTheSameInstant() {
        var edit = Entry.sample("x", on: .sample())
        edit.updatedAt = now
        var delete = edit
        delete.deletedAt = now
        #expect(MergePolicy.mergeItems(local: [edit], remote: [delete], now: now).first?.isDeleted == true)
        #expect(MergePolicy.mergeItems(local: [delete], remote: [edit], now: now).first?.isDeleted == true)
    }

    @Test func tieBreakIsSymmetric() {
        var lhs = Entry.sample("a", on: .sample())
        lhs.updatedAt = Timestamp(millis: 100)
        var rhs = lhs
        rhs.name = "b"
        let one = MergePolicy.mergeItems(local: [lhs], remote: [rhs], now: now)
        let other = MergePolicy.mergeItems(local: [rhs], remote: [lhs], now: now)
        #expect(one == other)
    }

    @Test func oldTombstonesArePurged() {
        var old = Entry.sample("old", on: .sample())
        old.updatedAt = now.adding(days: -91)
        old.deletedAt = old.updatedAt
        var recent = Entry.sample("recent", on: .sample())
        recent.updatedAt = now.adding(days: -89)
        recent.deletedAt = recent.updatedAt
        let merged = MergePolicy.mergeItems(local: [old, recent], remote: [], now: now)
        #expect(merged.map(\.name) == ["recent"])
    }

    @Test func unionKeepsItemsFromBothSides() {
        let board = Board.sample()
        let merged = MergePolicy.merge(
            local: LedgerSnapshot(boards: [board], entries: [.sample("a", on: board)]),
            remote: LedgerSnapshot(boards: [board], entries: [.sample("b", on: board)]),
            now: now
        )
        #expect(Set(merged.entries.map(\.name)) == ["a", "b"])
        #expect(merged.boards.count == 1)
    }
}
