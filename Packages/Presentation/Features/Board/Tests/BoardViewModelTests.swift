import Domain
import Foundation
import Testing

@testable import BoardFeature

@MainActor
final class FakeBoardActions: BoardActions {
    var savedBoards: [Board] = []
    var deletedEntries: [Entry] = []
    var edited: (entry: Entry?, boardId: UUID?)?
    var openedLinks: [String] = []
    var failSaves = false

    func saveBoard(_ board: Board) async throws {
        if failSaves { throw LedgerError.saveFailed }
        savedBoards.append(board)
    }

    func deleteBoard(_ board: Board) async throws {}

    func deleteEntry(_ entry: Entry) async throws {
        deletedEntries.append(entry)
    }

    func editEntry(_ entry: Entry?, boardId: UUID?) {
        edited = (entry, boardId)
    }

    func openQuickSearch() {}
    func requestSync() {}

    func openLink(_ link: String) {
        openedLinks.append(link)
    }

    func now() -> Timestamp { Timestamp(millis: 1_790_000_000_000) }
}

@MainActor
@Suite("BoardViewModel")
struct BoardViewModelTests {
    let actions = FakeBoardActions()
    let a = Board(
        name: "A",
        start: YearMonth(year: 2017, month: 7),
        end: YearMonth(year: 2019, month: 8),
        createdAt: Timestamp(millis: 0)
    )
    let b = Board(name: "B", start: YearMonth(year: 2019, month: 9), createdAt: Timestamp(millis: 0))

    func model() -> BoardViewModel {
        let model = BoardViewModel(actions: actions, sleep: { _ in })
        model.update(
            LedgerSnapshot(
                boards: [a, b],
                entries: [
                    Entry(
                        boardId: a.id,
                        name: "CI pipeline",
                        type: .dev,
                        date: DayDate(year: 2018, month: 5, day: 10),
                        createdAt: Timestamp(millis: 0)
                    ),
                    Entry(
                        boardId: b.id,
                        name: "Crash fix",
                        link: "https://example.com/1",
                        type: .bugFix,
                        date: DayDate(year: 2025, month: 11, day: 2),
                        createdAt: Timestamp(millis: 0)
                    ),
                    Entry(
                        boardId: b.id,
                        name: "Onboarding",
                        type: .product,
                        date: DayDate(year: 2025, month: 6, day: 20),
                        createdAt: Timestamp(millis: 0)
                    ),
                ]
            )
        )
        return model
    }

    @Test func boardsNewestFirstAndFiltering() {
        let model = model()
        #expect(model.boards.map(\.name) == ["B", "A"])
        #expect(model.visibleEntries.map(\.name) == ["Crash fix", "Onboarding", "CI pipeline"])
        model.selection = .board(b.id)
        #expect(model.visibleEntries.count == 2)
        model.toggle(.product)
        #expect(model.visibleEntries.map(\.name) == ["Onboarding"])
        model.toggle(.product)
        model.sort = .nameAscending
        #expect(model.visibleEntries.map(\.name) == ["Crash fix", "Onboarding"])
    }

    @Test func revealSwitchesBoardWhenFiltersHideTheEntry() throws {
        let model = model()
        model.selection = .board(b.id)
        model.toggle(.bugFix)
        let ci = try #require(model.snapshot.entries.first { $0.name == "CI pipeline" })
        model.reveal(ci.id)
        #expect(model.selection == .board(a.id))
        #expect(model.types.isEmpty)
        #expect(model.selectedEntry?.name == "CI pipeline")
    }

    @Test func selectionFallsBackWhenBoardDisappears() {
        let model = model()
        model.selection = .board(a.id)
        model.update(LedgerSnapshot(boards: [b]))
        #expect(model.selection == .all)
    }

    @Test func boardDraftValidatesAndSaves() async throws {
        let model = model()
        model.newBoard()
        var draft = try #require(model.boardDraft)
        #expect(draft.problem == "Enter a name.")
        draft.name = "  Company C "
        draft.isCurrent = false
        draft.start = YearMonth(year: 2020, month: 5)
        draft.end = YearMonth(year: 2020, month: 1)
        #expect(draft.problem == "The end comes before the start.")
        await model.saveBoardDraft(draft)
        #expect(actions.savedBoards.isEmpty)
        draft.end = YearMonth(year: 2021, month: 1)
        await model.saveBoardDraft(draft)
        #expect(actions.savedBoards.map(\.name) == ["Company C"])
        #expect(actions.savedBoards.first?.end == YearMonth(year: 2021, month: 1))
        #expect(model.boardDraft == nil)
        #expect(model.selection == .board(draft.id))
        #expect(model.toast == "Board added")
    }

    @Test func failedSaveKeepsTheSheetOpen() async throws {
        let model = model()
        actions.failSaves = true
        model.editBoard(a)
        await model.saveBoardDraft(try #require(model.boardDraft))
        #expect(model.boardDraft != nil)
        #expect(model.errorMessage == "Couldn't save the board.")
    }

    @Test func newEntryTargetsTheSelectedBoard() {
        let model = model()
        model.selection = .board(a.id)
        model.newEntry()
        #expect(actions.edited?.boardId == a.id)
        #expect(actions.edited?.entry == nil)
    }
}
