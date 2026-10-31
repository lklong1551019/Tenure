import Domain
import Foundation
import Observation

/// What the board needs from the app. Data arrives through `BoardViewModel.update(_:)`;
/// every change goes back through here and returns once it is saved.
@MainActor
public protocol BoardActions: AnyObject {
    func saveBoard(_ board: Board) async throws
    func deleteBoard(_ board: Board) async throws
    func deleteEntry(_ entry: Entry) async throws
    /// Opens the editor; nil creates a new entry, on `boardId` when one is given.
    func editEntry(_ entry: Entry?, boardId: UUID?)
    func openQuickSearch()
    /// The toolbar sync button: one round now, if signed in.
    func requestSync()
    func openLink(_ link: String)
    func copyText(_ text: String)
    func now() -> Timestamp
}

public enum BoardSelection: Hashable, Sendable {
    case all
    case board(UUID)
}

/// A year on the board's year menu and how many of the board's tasks fall in it.
public struct YearCount: Hashable, Sendable {
    public let year: Int
    public let count: Int
}

public enum BoardLayout: String, CaseIterable, Sendable {
    case grid
    case list
}

/// The board sheet's fields, for a new board or an existing one.
public struct BoardDraft: Identifiable, Sendable, Equatable {
    public let id: UUID
    let original: Board?
    public var name: String
    public var start: YearMonth
    public var isCurrent: Bool
    public var end: YearMonth

    init(_ board: Board?, today: YearMonth) {
        id = board?.id ?? UUID()
        original = board
        name = board?.name ?? ""
        start = board?.start ?? today
        isCurrent = board.map(\.isCurrent) ?? true
        end = board?.end ?? today
    }

    public var isNew: Bool { original == nil }

    /// Nil while the name is empty or the range runs backwards.
    public var problem: String? {
        if name.trimmingCharacters(in: .whitespaces).isEmpty { return "Enter a name." }
        if !isCurrent && end < start { return "The end comes before the start." }
        return nil
    }

    func board(createdAt: Timestamp) -> Board {
        Board(
            id: id,
            name: name.trimmingCharacters(in: .whitespaces),
            start: start,
            end: isCurrent ? nil : end,
            createdAt: original?.createdAt ?? createdAt
        )
    }
}

/// The year sheet's choices.
public struct YearExportDraft: Identifiable, Sendable, Equatable {
    public let id = UUID()
    public var year: Int
    /// Nil exports every board.
    public var boardId: UUID?
    public var options = MarkdownOptions()
}

/// A Markdown file waiting for the save panel.
public struct ExportFile: Identifiable, Sendable, Equatable {
    public let id = UUID()
    /// Without the extension.
    public let name: String
    public let text: String
}

@MainActor
@Observable
public final class BoardViewModel {
    static let toastDuration: Duration = .milliseconds(2400)

    public private(set) var snapshot = LedgerSnapshot.empty
    /// Set by the app while signed in to Google Drive; nil hides the toolbar indicator.
    public var syncStatus: SyncStatus?
    // Each filter refreshes the visible tasks when it really changes. Changes made together
    // (clearing filters, revealing a task, a new snapshot) go through `batch`, which refreshes
    // once at the end instead of once per property.
    public var selection: BoardSelection = .all {
        didSet {
            guard selection != oldValue else { return }
            selectedEntryId = nil
            refresh(years: true)
        }
    }
    /// Empty shows every kind.
    public var types: Set<EntryType> = [] {
        didSet { if types != oldValue { refresh() } }
    }
    /// Nil shows every year.
    public var year: Int? {
        didSet { if year != oldValue { refresh() } }
    }
    public var text = "" {
        didSet { if text != oldValue { refresh() } }
    }
    public var sort: EntrySort = .newest {
        didSet { if sort != oldValue { refresh() } }
    }
    @ObservationIgnored private var isBatching = false
    @ObservationIgnored private var needsYears = false
    @ObservationIgnored private var needsVisible = false

    // Derived from `snapshot` once per update, not on every read: views read these many times
    // per redraw, and with thousands of tasks recomputing them made each click lag.
    /// Live boards, newest first.
    public private(set) var boards: [Board] = []
    /// Live tasks, in file order.
    public private(set) var liveEntries: [Entry] = []
    /// What the grid or table shows: the board, kinds, year, text filter, and sort applied.
    public private(set) var visibleEntries: [Entry] = []
    /// Kinds to offer as filter chips: the known ones, then any others found in the data.
    public private(set) var availableTypes = EntryType.known
    /// Years with tasks on the selected board (every board on All tasks), newest first. A
    /// task spanning two years counts in both.
    public private(set) var years: [YearCount] = []
    private var boardNames: [UUID: String] = [:]
    /// Live tasks per board.
    private var taskCounts: [UUID: Int] = [:]

    public var layout: BoardLayout = .grid
    public var selectedEntryId: UUID?
    public var boardDraft: BoardDraft?
    /// The keyboard shortcuts sheet (Cmd-/).
    public var showsShortcuts = false
    public var yearExport: YearExportDraft?
    /// Set when a file is ready; the view shows the save panel.
    public var exportFile: ExportFile?
    public private(set) var toast: String?
    public private(set) var errorMessage: String?
    /// Bumped by Cmd+F; the view moves focus to the toolbar filter field on each change.
    public private(set) var searchFocusRequests = 0

    private let actions: any BoardActions
    private let sleep: @Sendable (Duration) async -> Void
    private var toastTask: Task<Void, Never>?

    public init(
        actions: any BoardActions,
        sleep: @escaping @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    ) {
        self.actions = actions
        self.sleep = sleep
    }

    // MARK: Data

    /// Called by the app with every new snapshot, local or synced in. The same snapshot can
    /// arrive twice (the save path and the change stream); the second is ignored.
    public func update(_ snapshot: LedgerSnapshot) {
        guard snapshot != self.snapshot else { return }
        batch { apply(snapshot) }
    }

    private func apply(_ snapshot: LedgerSnapshot) {
        self.snapshot = snapshot
        boards = snapshot.liveBoards
        liveEntries = snapshot.liveEntries
        boardNames = Dictionary(boards.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        taskCounts = liveEntries.reduce(into: [:]) { counts, entry in counts[entry.boardId, default: 0] += 1 }
        let extra = Set(liveEntries.map(\.type)).subtracting(EntryType.known)
        availableTypes = EntryType.known + extra.sorted { $0.rawValue < $1.rawValue }
        if case .board(let id) = selection, boardNames[id] == nil {
            selection = .all
        }
        if let id = selectedEntryId, !liveEntries.contains(where: { $0.id == id }) {
            selectedEntryId = nil
        }
        refresh(years: true)
    }

    /// Runs `changes`, then refreshes whatever they touched once.
    private func batch(_ changes: () -> Void) {
        isBatching = true
        changes()
        isBatching = false
        refresh()
    }

    /// Marks the derived lists stale and, outside a batch, recomputes them.
    private func refresh(years: Bool = false) {
        needsYears = needsYears || years
        needsVisible = true
        guard !isBatching else { return }
        if needsYears {
            needsYears = false
            refreshYears()
        }
        if needsVisible {
            needsVisible = false
            visibleEntries = query.apply(to: liveEntries)
        }
    }

    /// Recounts the year menu for the current board; drops a chosen year it no longer has.
    private func refreshYears() {
        let boardId = selectedBoard?.id
        var counts: [Int: Int] = [:]
        for entry in liveEntries where boardId == nil || entry.boardId == boardId {
            for year in entry.years {
                counts[year, default: 0] += 1
            }
        }
        years = counts.map { YearCount(year: $0.key, count: $0.value) }.sorted { $0.year > $1.year }
        if let year, counts[year] == nil {
            // Inside refresh: the visible list is recomputed right after.
            isBatching = true
            self.year = nil
            isBatching = false
        }
    }

    /// Whether any filter narrows the tasks: kinds, a year, or text.
    public var hasFilters: Bool {
        !types.isEmpty || year != nil || !text.isEmpty
    }

    public var selectedBoard: Board? {
        guard case .board(let id) = selection else { return nil }
        return boards.first { $0.id == id }
    }

    private var query: EntryQuery {
        EntryQuery(boardId: selectedBoard?.id, types: types, year: year, text: text, sort: sort)
    }

    public var selectedEntry: Entry? {
        guard let id = selectedEntryId else { return nil }
        return liveEntries.first { $0.id == id }
    }

    public func entryCount(of board: Board?) -> Int {
        guard let board else { return liveEntries.count }
        return taskCounts[board.id] ?? 0
    }

    public func boardName(of entry: Entry) -> String {
        boardNames[entry.boardId] ?? ""
    }

    public var title: String {
        selectedBoard?.name ?? "All tasks"
    }

    /// Under the board's name: "Jan 2024 - now · 9 tasks", "9 tasks · 2 boards" on All tasks,
    /// and with a year chosen, "Jan 2024 - now · 4 of 9 tasks · 2026".
    public var summary: String {
        let total = entryCount(of: selectedBoard)
        let tasks: String
        if let year {
            let inYear = years.first { $0.year == year }?.count ?? 0
            tasks = "\(inYear) of \(total.counted("task"))"
        } else {
            tasks = total.counted("task")
        }
        let parts: [String?] = [
            selectedBoard?.period(\.short),
            tasks,
            selectedBoard == nil && year == nil ? boards.count.counted("board") : nil,
            year.map { String($0) },
        ]
        return parts.compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: Filters

    public func toggle(_ type: EntryType) {
        if types.contains(type) {
            types.remove(type)
        } else {
            types.insert(type)
        }
    }

    public func clearFilters() {
        batch {
            types = []
            year = nil
            text = ""
        }
    }

    public func focusSearch() {
        searchFocusRequests += 1
    }

    // MARK: Boards

    public func newBoard() {
        boardDraft = BoardDraft(nil, today: YearMonth(actions.now().date))
    }

    public func editBoard(_ board: Board) {
        boardDraft = BoardDraft(board, today: YearMonth(actions.now().date))
    }

    /// `draft` is the sheet's edited copy of `boardDraft`.
    public func saveBoardDraft(_ draft: BoardDraft) async {
        guard draft.problem == nil else { return }
        await perform("Couldn't save the board.") {
            try await self.actions.saveBoard(draft.board(createdAt: self.actions.now()))
            self.boardDraft = nil
            if draft.isNew { self.selection = .board(draft.id) }
            self.show(draft.isNew ? "Board added" : "Board saved")
        }
    }

    public func deleteBoard(_ board: Board) async {
        await perform("Couldn't delete the board.") {
            try await self.actions.deleteBoard(board)
            self.show("Board deleted")
        }
    }

    // MARK: Entries

    public func newEntry() {
        actions.editEntry(nil, boardId: selectedBoard?.id ?? boards.first?.id)
    }

    public func edit(_ entry: Entry) {
        actions.editEntry(entry, boardId: entry.boardId)
    }

    public func delete(_ entry: Entry) async {
        await perform("Couldn't delete the task.") {
            try await self.actions.deleteEntry(entry)
            self.show("Task deleted")
        }
    }

    /// Selects an entry found elsewhere (quick search), switching boards when the filters
    /// would hide it.
    public func reveal(_ entryId: UUID) {
        guard let entry = liveEntries.first(where: { $0.id == entryId }) else { return }
        if !query.apply(to: [entry]).isEmpty {
            selectedEntryId = entryId
            return
        }
        batch {
            types = []
            year = nil
            text = ""
            selection = .board(entry.boardId)
        }
        selectedEntryId = entryId
    }

    public func openLink(of entry: Entry) {
        guard let link = entry.link, !link.isEmpty else { return }
        actions.openLink(link)
    }

    /// A link inside a task's story. The app decides which links may open.
    public func openLink(_ link: String) {
        actions.openLink(link)
    }

    public func openQuickSearch() {
        actions.openQuickSearch()
    }

    // MARK: Export

    public var canExport: Bool { !liveEntries.isEmpty }

    /// The selected board, or every board on All tasks.
    public func exportCurrent() {
        let today = DayDate(actions.now().date)
        if let board = selectedBoard {
            let text = MarkdownExport.board(board, entries: liveEntries, exportedOn: today)
            exportFile = ExportFile(name: MarkdownExport.fileName(board.name), text: text)
        } else {
            let text = MarkdownExport.all(boards: boards, entries: liveEntries, exportedOn: today)
            exportFile = ExportFile(name: "Tenure", text: text)
        }
    }

    /// Years with tasks, newest first.
    public var exportYears: [Int] {
        MarkdownExport.years(of: liveEntries)
    }

    public func beginYearExport() {
        guard let year = exportYears.first else { return }
        yearExport = YearExportDraft(year: year, boardId: selectedBoard?.id)
    }

    /// "5 tasks from 2 boards", for the year sheet.
    public func yearExportSummary(_ draft: YearExportDraft) -> String {
        let groups = MarkdownExport.yearGroups(
            draft.year,
            boards: boards,
            entries: liveEntries,
            boardId: draft.boardId
        )
        let tasks = groups.reduce(0) { $0 + $1.entries.count }
        return "\(tasks.counted("task")) from \(groups.count.counted("board")), dated in \(draft.year)."
    }

    /// `draft` is the sheet's edited copy of `yearExport`.
    public func exportYear(_ draft: YearExportDraft) {
        let text = MarkdownExport.year(
            draft.year,
            boards: boards,
            entries: liveEntries,
            boardId: draft.boardId,
            options: draft.options,
            exportedOn: DayDate(actions.now().date)
        )
        let boardName = draft.boardId.flatMap { id in boards.first { $0.id == id }?.name }
        let name = [boardName ?? "Tenure", String(draft.year)].joined(separator: " ")
        yearExport = nil
        exportFile = ExportFile(name: MarkdownExport.fileName(name), text: text)
    }

    /// Called by the view once the save panel has written the file, or failed to.
    public func finishExport(_ result: Result<Void, any Error>) {
        exportFile = nil
        switch result {
        case .success: show("Exported")
        case .failure: errorMessage = "Couldn't save the file."
        }
    }

    public func copySelectedEntry() {
        guard let entry = selectedEntry else { return }
        actions.copyText(MarkdownExport.entry(entry))
        show("Copied as Markdown")
    }

    public func requestSync() {
        actions.requestSync()
    }

    public func dismissError() {
        errorMessage = nil
    }

    // MARK: Private

    private func perform(_ failure: String, _ body: () async throws -> Void) async {
        do {
            try await body()
            errorMessage = nil
        } catch {
            errorMessage = failure
        }
    }

    private func show(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { [sleep] in
            await sleep(Self.toastDuration)
            guard !Task.isCancelled else { return }
            self.toast = nil
        }
    }
}
