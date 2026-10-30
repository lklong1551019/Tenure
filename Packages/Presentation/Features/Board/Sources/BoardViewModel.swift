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
    func now() -> Timestamp
}

public enum BoardSelection: Hashable, Sendable {
    case all
    case board(UUID)
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

@MainActor
@Observable
public final class BoardViewModel {
    static let toastDuration: Duration = .milliseconds(2400)

    public private(set) var snapshot = LedgerSnapshot.empty
    /// Set by the app while signed in to Google Drive; nil hides the toolbar indicator.
    public var syncStatus: SyncStatus?
    public var selection: BoardSelection = .all {
        didSet { selectedEntryId = nil }
    }
    /// Empty shows every kind.
    public var types: Set<EntryType> = []
    public var text = ""
    public var sort: EntrySort = .newest
    public var layout: BoardLayout = .grid
    public var selectedEntryId: UUID?
    public var boardDraft: BoardDraft?
    /// The keyboard shortcuts sheet (Cmd-/).
    public var showsShortcuts = false
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

    /// Called by the app with every new snapshot, local or synced in.
    public func update(_ snapshot: LedgerSnapshot) {
        self.snapshot = snapshot
        if case .board(let id) = selection, !snapshot.liveBoards.contains(where: { $0.id == id }) {
            selection = .all
        }
        if let id = selectedEntryId, !snapshot.liveEntries.contains(where: { $0.id == id }) {
            selectedEntryId = nil
        }
    }

    public var boards: [Board] { snapshot.liveBoards }

    public var selectedBoard: Board? {
        guard case .board(let id) = selection else { return nil }
        return boards.first { $0.id == id }
    }

    public var query: EntryQuery {
        EntryQuery(boardId: selectedBoard?.id, types: types, text: text, sort: sort)
    }

    public var visibleEntries: [Entry] {
        query.apply(to: snapshot.liveEntries)
    }

    public var selectedEntry: Entry? {
        guard let id = selectedEntryId else { return nil }
        return snapshot.liveEntries.first { $0.id == id }
    }

    public func entryCount(of board: Board?) -> Int {
        guard let board else { return snapshot.liveEntries.count }
        return snapshot.liveEntries.count { $0.boardId == board.id }
    }

    public func boardName(of entry: Entry) -> String {
        boards.first { $0.id == entry.boardId }?.name ?? ""
    }

    /// Kinds to offer as filter chips: the known ones, then any others found in the data.
    public var availableTypes: [EntryType] {
        let extra = Set(snapshot.liveEntries.map(\.type)).subtracting(EntryType.known)
        return EntryType.known + extra.sorted { $0.rawValue < $1.rawValue }
    }

    public var title: String {
        selectedBoard?.name ?? "All tasks"
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
        types = []
        text = ""
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
        guard let entry = snapshot.liveEntries.first(where: { $0.id == entryId }) else { return }
        if !query.apply(to: [entry]).isEmpty {
            selectedEntryId = entryId
            return
        }
        clearFilters()
        selection = .board(entry.boardId)
        selectedEntryId = entryId
    }

    public func openLink(of entry: Entry) {
        guard let link = entry.link, !link.isEmpty else { return }
        actions.openLink(link)
    }

    public func openQuickSearch() {
        actions.openQuickSearch()
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
