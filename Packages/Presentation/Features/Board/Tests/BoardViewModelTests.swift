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

    var copied: [String] = []

    func copyText(_ text: String) {
        copied.append(text)
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

    @Test func exportsTheSelectedBoardOrEveryBoard() {
        let model = model()
        model.exportCurrent()
        #expect(model.exportFile?.name == "Tenure")
        #expect(model.exportFile?.text.hasPrefix("# Tenure") == true)
        model.selection = .board(b.id)
        model.exportCurrent()
        #expect(model.exportFile?.name == "B")
        #expect(model.exportFile?.text.contains("## Onboarding") == true)
        #expect(model.exportFile?.text.contains("CI pipeline") == false)
        model.finishExport(.success(()))
        #expect(model.exportFile == nil)
        #expect(model.toast == "Exported")
    }

    @Test func yearExportStartsOnTheNewestYearAndNamesTheFile() throws {
        let model = model()
        #expect(model.exportYears == [2025, 2018])
        model.selection = .board(a.id)
        model.beginYearExport()
        var draft = try #require(model.yearExport)
        #expect(draft.year == 2025)
        #expect(draft.boardId == a.id)
        draft.year = 2018
        #expect(model.yearExportSummary(draft) == "1 task from 1 board, dated in 2018.")
        model.exportYear(draft)
        #expect(model.yearExport == nil)
        #expect(model.exportFile?.name == "A 2018")
        #expect(model.exportFile?.text.contains("### CI pipeline") == true)
    }

    @Test func copiesTheSelectedTask() {
        let model = model()
        model.copySelectedEntry()
        #expect(actions.copied.isEmpty)
        model.selectedEntryId = model.visibleEntries.first?.id
        model.copySelectedEntry()
        #expect(actions.copied.first?.hasPrefix("# Crash fix") == true)
        #expect(model.summary == "3 tasks · 2 boards")
        model.selection = .board(a.id)
        #expect(model.summary == "Jul 2017 - Aug 2019 · 1 task")
    }

    @Test func storyTextReadsHTMLTagsAsMarkdown() {
        #expect(StoryText.markdown("<b>access</b> and <EM>why</EM><br/>next") == "**access** and *why*\nnext")
        let bold = StoryText.attributed("<b>access history</b> was slow")
        #expect(String(bold.characters) == "access history was slow")
        let runs = bold.runs.map { $0.inlinePresentationIntent }
        #expect(runs.first == .stronglyEmphasized)
        #expect(String(StoryText.attributed("**done** `x`").characters) == "done x")
    }
}
