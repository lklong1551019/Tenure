import DesignSystem
import Domain
import SwiftUI

/// The main window: boards on the left, tasks in the middle as a grid or a table, and the
/// selected task's story on the right.
public struct BoardView: View {
    @Bindable private var model: BoardViewModel
    @FocusState private var isSearchFocused: Bool
    @State private var pendingDelete: PendingDelete?
    /// Layout and sort survive relaunches; filters and selection start fresh.
    @AppStorage("boardLayout") private var storedLayout: BoardLayout = .grid
    @AppStorage("entrySort") private var storedSort: EntrySort = .newest
    /// Share of the space right of the sidebar that the task list takes; the story gets the rest.
    @AppStorage("listRatio") private var listRatio = Self.defaultListRatio
    /// `listRatio` when the current drag of the split handle began.
    @State private var dragStartRatio: Double?

    static let defaultListRatio = 0.4
    static let minimumListWidth: CGFloat = 320
    static let minimumDetailWidth: CGFloat = 360

    public init(model: BoardViewModel) {
        self.model = model
    }

    public var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 300)
        } detail: {
            // Tasks and the selected task's story, 40 to 60 until the handle is dragged.
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    content
                        .frame(width: listWidth(in: proxy.size.width))
                    splitHandle(totalWidth: proxy.size.width)
                    detail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .searchable(text: $model.text, placement: .toolbar, prompt: "Filter tasks (Cmd+F)")
        .searchFocused($isSearchFocused)
        .onChange(of: model.searchFocusRequests) { isSearchFocused = true }
        .onAppear {
            model.layout = storedLayout
            model.sort = storedSort
        }
        .onChange(of: model.layout) { storedLayout = model.layout }
        .onChange(of: model.sort) { storedSort = model.sort }
        .sheet(item: $model.boardDraft) { draft in
            BoardEditorView(
                draft: draft,
                onSave: { edited in Task { await model.saveBoardDraft(edited) } },
                onCancel: { model.boardDraft = nil }
            )
        }
        .sheet(isPresented: $model.showsShortcuts) {
            ShortcutsView { model.showsShortcuts = false }
        }
        .sheet(item: $model.yearExport) { draft in
            YearExportView(
                draft: draft,
                years: model.exportYears,
                boards: model.boards,
                summary: model.yearExportSummary,
                onExport: model.exportYear,
                onCancel: { model.yearExport = nil }
            )
        }
        .fileExporter(
            isPresented: Binding(present: $model.exportFile),
            document: model.exportFile.map { MarkdownDocument(text: $0.text) },
            contentType: MarkdownDocument.markdown,
            defaultFilename: model.exportFile?.name
        ) { result in
            // Not called on Cancel; the binding clears the file then.
            model.finishExport(result.map { _ in () })
        }
        .confirmationDialog(
            pendingDelete?.title ?? "",
            isPresented: Binding(present: $pendingDelete),
            presenting: pendingDelete
        ) { item in
            Button("Delete", role: .destructive) {
                Task {
                    switch item {
                    case .board(let board): await model.deleteBoard(board)
                    case .entry(let entry): await model.delete(entry)
                    }
                }
            }
        } message: { item in
            Text(item.message)
        }
    }

    // MARK: Split

    private func listWidth(in total: CGFloat) -> CGFloat {
        let upper = max(Self.minimumListWidth, total - Self.minimumDetailWidth)
        return min(max(total * listRatio, Self.minimumListWidth), upper)
    }

    /// A hairline with a wider grab area. Drag to resize; double-click to go back to 40/60.
    private func splitHandle(totalWidth: CGFloat) -> some View {
        Rectangle()
            .fill(Palette.border)
            .frame(width: 1)
            .padding(.horizontal, 3)
            .contentShape(Rectangle())
            .pointerStyle(.frameResize(position: .trailing))
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { drag in
                        guard totalWidth > Self.minimumListWidth + Self.minimumDetailWidth else { return }
                        let start = dragStartRatio ?? listRatio
                        dragStartRatio = start
                        // Kept within what both columns' minimums allow, so dragging back
                        // responds at once instead of first undoing an overshoot.
                        let lowest = Self.minimumListWidth / totalWidth
                        let highest = (totalWidth - Self.minimumDetailWidth) / totalWidth
                        listRatio = min(max(start + drag.translation.width / totalWidth, lowest), highest)
                    }
                    .onEnded { _ in dragStartRatio = nil }
            )
            .onTapGesture(count: 2) { listRatio = Self.defaultListRatio }
            .accessibilityLabel("Resize task list")
            .help("Drag to resize; double-click for 40/60")
    }

    // MARK: Sidebar

    private var sidebar: some View {
        List(selection: Binding(get: { model.selection }, set: { model.selection = $0 ?? .all })) {
            Label {
                HStack {
                    Text("All tasks")
                    Spacer()
                    count(model.entryCount(of: nil))
                }
            } icon: {
                Image(systemName: "square.stack.3d.up")
            }
            .tag(BoardSelection.all)
            Section("Boards") {
                ForEach(model.boards) { board in
                    boardRow(board)
                        .tag(BoardSelection.board(board.id))
                        .contextMenu {
                            Button("Edit board...") { model.editBoard(board) }
                            Button("Export as Markdown...") {
                                model.selection = .board(board.id)
                                model.exportCurrent()
                            }
                            .disabled(model.entryCount(of: board) == 0)
                            Button("Delete board...", role: .destructive) { pendingDelete = .board(board) }
                        }
                }
                Button {
                    model.newBoard()
                } label: {
                    Label("New board", systemImage: "plus")
                        .foregroundStyle(Palette.secondaryInk)
                }
                .buttonStyle(.plain)
                .help("New board (Shift-Cmd-N)")
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            ShortcutHint { model.showsShortcuts = true }
        }
    }

    private func boardRow(_ board: Board) -> some View {
        Label {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(board.name)
                    Text(board.period)
                        .appFont(11)
                        .foregroundStyle(Palette.mutedInk)
                }
                Spacer()
                count(model.entryCount(of: board))
            }
        } icon: {
            // Filled for the job you hold now, hollow for past ones.
            Image(systemName: board.isCurrent ? "circle.fill" : "circle")
                .appFont(8)
                .foregroundStyle(board.isCurrent ? Palette.accent : Palette.mutedInk)
        }
    }

    private func count(_ value: Int) -> some View {
        Text("\(value)")
            .appFont(11)
            .foregroundStyle(Palette.mutedInk)
            .monospacedDigit()
    }

    // MARK: Content

    private var content: some View {
        VStack(spacing: 0) {
            if !model.boards.isEmpty {
                boardHeader
                filterBar
            }
            if let message = model.errorMessage {
                HStack {
                    ErrorLine(message)
                    Spacer()
                    Button("Dismiss", systemImage: "xmark") { model.dismissError() }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }
            if model.boards.isEmpty {
                emptyState(
                    "Start with a board",
                    "A board is one stretch of your career, like a company and the years you spent there.",
                    action: ("New board", model.newBoard)
                )
            } else if model.visibleEntries.isEmpty {
                if model.text.isEmpty && model.types.isEmpty {
                    emptyState(
                        "Write down what you shipped",
                        "Add a task with the problem, the fix, and the numbers that prove it.",
                        action: ("New task", model.newEntry)
                    )
                } else {
                    emptyState(
                        "No tasks match",
                        "Change the filters to see more.",
                        action: ("Clear filters", model.clearFilters)
                    )
                }
            } else {
                switch model.layout {
                case .grid: grid
                case .list: table
                }
            }
        }
        .background(Palette.ground)
        .navigationTitle(model.title)
        .navigationSubtitle(model.selectedBoard?.period ?? "")
        .toolbar { contentToolbar }
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                Toast(toast)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.toast)
    }

    /// The board's name and span, with the actions that belong to it. The buttons move under
    /// the title when the column is narrow.
    private var boardHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: 10) {
                boardTitle
                Spacer(minLength: 12)
                boardActions
            }
            VStack(alignment: .leading, spacing: 12) {
                boardTitle
                HStack(spacing: 10) { boardActions }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    private var boardTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.title)
                .appFont(24, weight: .bold)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            Text(model.summary)
                .appFont(13)
                .foregroundStyle(Palette.mutedInk)
                .fixedSize()
        }
    }

    @ViewBuilder
    private var boardActions: some View {
        Menu {
            Button(model.selectedBoard.map { "\($0.name) as Markdown..." } ?? "All boards as Markdown...") {
                model.exportCurrent()
            }
            Button("A year as Markdown...") { model.beginYearExport() }
            Divider()
            Button("Copy task as Markdown") { model.copySelectedEntry() }
                .disabled(model.selectedEntry == nil)
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .menuStyle(.button)
        .fixedSize()
        .disabled(!model.canExport)
        .help("Export to Markdown")
        Button {
            model.newEntry()
        } label: {
            Label("New task", systemImage: "plus")
        }
        .buttonStyle(PrimaryButtonStyle())
        .fixedSize()
        .help("New task (Cmd-N)")
    }

    private var filterBar: some View {
        HStack(alignment: .top, spacing: 8) {
            FlowRow(spacing: 8) {
                FilterChip("All kinds", tint: .teal, isOn: model.types.isEmpty) {
                    model.types = []
                }
                ForEach(model.availableTypes, id: \.self) { type in
                    FilterChip(type.title, tint: type.tint, isOn: model.types.contains(type)) {
                        model.toggle(type)
                    }
                }
            }
            if !model.types.isEmpty || !model.text.isEmpty {
                Text("\(model.visibleEntries.count) shown")
                    .appFont(12)
                    .foregroundStyle(Palette.mutedInk)
                    .fixedSize()
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
                ForEach(model.visibleEntries) { entry in
                    EntryCard(
                        entry: entry,
                        boardName: model.selectedBoard == nil ? model.boardName(of: entry) : nil,
                        isSelected: model.selectedEntryId == entry.id
                    )
                    // Select on the first click; a double-click alongside it opens the editor.
                    // Stacking onTapGesture(count: 2) above onTapGesture would hold every
                    // single click until the double-click interval passed.
                    .onTapGesture { model.selectedEntryId = entry.id }
                    .simultaneousGesture(TapGesture(count: 2).onEnded { model.edit(entry) })
                    .contextMenu { entryMenu(entry) }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }

    private var table: some View {
        Table(model.visibleEntries, selection: $model.selectedEntryId, sortOrder: sortOrder) {
            TableColumn("Kind") { entry in
                Badge(entry.type.title, tint: entry.type.tint)
            }
            .width(min: 70, ideal: 80, max: 100)
            TableColumn("Name", value: \Entry.name, comparator: .localizedStandard) { entry in
                Text(entry.displayName)
            }
            TableColumn("Board") { entry in
                Text(model.boardName(of: entry)).foregroundStyle(Palette.secondaryInk)
            }
            .width(min: 80, ideal: 120)
            TableColumn("Link") { entry in
                Text(entry.link ?? "").foregroundStyle(Palette.accentInk).lineLimit(1).truncationMode(.middle)
            }
            .width(min: 60, ideal: 120)
            TableColumn("Date", value: \Entry.date) { entry in
                Text(entry.date.short).monospacedDigit()
            }
            .width(min: 90, ideal: 100)
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            if let id = ids.first, let entry = model.visibleEntries.first(where: { $0.id == id }) {
                entryMenu(entry)
            }
        } primaryAction: { ids in
            if let id = ids.first, let entry = model.visibleEntries.first(where: { $0.id == id }) {
                model.edit(entry)
            }
        }
    }

    /// The table's header sort, kept in step with the toolbar's sort menu.
    private var sortOrder: Binding<[KeyPathComparator<Entry>]> {
        Binding(
            get: {
                switch model.sort {
                case .newest: [KeyPathComparator(\Entry.date, order: .reverse)]
                case .oldest: [KeyPathComparator(\Entry.date, order: .forward)]
                case .nameAscending: [KeyPathComparator(\Entry.name, comparator: .localizedStandard, order: .forward)]
                case .nameDescending: [KeyPathComparator(\Entry.name, comparator: .localizedStandard, order: .reverse)]
                }
            },
            set: { comparators in
                guard let first = comparators.first else { return }
                let isName = first.keyPath == \Entry.name
                switch (isName, first.order) {
                case (true, .forward): model.sort = .nameAscending
                case (true, .reverse): model.sort = .nameDescending
                case (false, .forward): model.sort = .oldest
                case (false, .reverse): model.sort = .newest
                }
            }
        )
    }

    @ViewBuilder
    private func entryMenu(_ entry: Entry) -> some View {
        Button("Edit...") { model.edit(entry) }
        if entry.link?.isEmpty == false {
            Button("Open link") { model.openLink(of: entry) }
        }
        Button("Copy as Markdown") {
            model.selectedEntryId = entry.id
            model.copySelectedEntry()
        }
        Divider()
        Button("Delete...", role: .destructive) { pendingDelete = .entry(entry) }
    }

    private func emptyState(_ title: String, _ message: String, action: (String, () -> Void)) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .appFont(17, weight: .semibold)
                .foregroundStyle(Palette.ink)
            Text(message)
                .appFont(13)
                .foregroundStyle(Palette.secondaryInk)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
            Button(action.0, action: action.1)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    @ToolbarContentBuilder
    private var contentToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Picker("Layout", selection: $model.layout) {
                Label("Grid", systemImage: "square.grid.2x2").tag(BoardLayout.grid)
                Label("List", systemImage: "list.bullet").tag(BoardLayout.list)
            }
            .pickerStyle(.segmented)
            .help("Grid (Cmd-1) or list (Cmd-2)")
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Picker("Sort", selection: $model.sort) {
                    Text("Newest first").tag(EntrySort.newest)
                    Text("Oldest first").tag(EntrySort.oldest)
                    Text("Name A-Z").tag(EntrySort.nameAscending)
                    Text("Name Z-A").tag(EntrySort.nameDescending)
                }
                .pickerStyle(.inline)
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
            .help("Sort tasks")
        }
        if let status = model.syncStatus {
            ToolbarItem(placement: .primaryAction) {
                SyncStatusButton(status: status) { model.requestSync() }
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                model.openQuickSearch()
            } label: {
                Label("Quick search", systemImage: "magnifyingglass")
            }
            .help("Find a task (Cmd-K)")
        }
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        if let entry = model.selectedEntry {
            EntryDetailView(
                entry: entry,
                boardName: model.boardName(of: entry),
                onEdit: { model.edit(entry) },
                onDelete: { pendingDelete = .entry(entry) },
                onOpenLink: { model.openLink(of: entry) },
                onCopy: { model.copySelectedEntry() }
            )
        } else {
            Text("Select a task to see its story.")
                .appFont(13)
                .foregroundStyle(Palette.secondaryInk)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.ground)
        }
    }
}

private enum PendingDelete: Identifiable {
    case board(Board)
    case entry(Entry)

    var id: UUID {
        switch self {
        case .board(let board): board.id
        case .entry(let entry): entry.id
        }
    }

    var title: String {
        switch self {
        case .board(let board): "Delete \"\(board.name)\"?"
        case .entry(let entry): "Delete \"\(entry.name)\"?"
        }
    }

    var message: String {
        switch self {
        case .board: "The board and every task on it are deleted, on this Mac and in Google Drive."
        case .entry: "The task is deleted, on this Mac and in Google Drive."
        }
    }
}

private struct SyncStatusButton: View {
    let status: SyncStatus
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .symbolEffect(.rotate, isActive: status == .syncing)
                .foregroundStyle(isProblem ? Palette.danger : Palette.secondaryInk)
        }
        .disabled(status == .syncing)
        .help(help)
        .accessibilityLabel(help)
    }

    private var symbol: String {
        switch status {
        case .idle: "icloud"
        case .syncing: "arrow.triangle.2.circlepath"
        case .synced: "checkmark.icloud"
        case .failed(let error, _): error.needsAttention ? "exclamationmark.icloud" : "icloud.slash"
        }
    }

    private var isProblem: Bool {
        if case .failed(let error, _) = status { return error.needsAttention }
        return false
    }

    private var help: String {
        switch status {
        case .idle: "Google Drive: not synced yet. Click to sync now."
        case .syncing: "Syncing with Google Drive..."
        case .synced: "Synced with Google Drive. Click to sync now."
        case .failed(let error, _): error.message
        }
    }
}
