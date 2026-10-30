import Domain
import Foundation
import Observation

@MainActor
public protocol QuickSearchActions: AnyObject {
    func searchableEntries() async -> [Entry]
    func boardName(of entry: Entry) -> String
    /// Selects the entry on the board. Called after the palette closes.
    func show(_ entry: Entry)
    func openLink(_ link: String)
    func closeQuickSearch()
}

/// Cmd+K: type, arrow to a task, Return shows it on the board, Cmd+Return opens its link.
@MainActor
@Observable
public final class QuickSearchViewModel: Identifiable {
    static let maximumResults = 8

    public nonisolated let id = UUID()
    public var query = "" {
        didSet {
            selectedIndex = 0
            refresh()
        }
    }
    public private(set) var selectedIndex = 0
    /// The best matches, or the newest tasks while the query is empty. Ranked once per change
    /// of the query or the tasks, not on every read.
    public private(set) var results: [Entry] = []

    private var entries: [Entry] = []
    private let actions: any QuickSearchActions

    public init(actions: any QuickSearchActions) {
        self.actions = actions
    }

    public var selected: Entry? {
        results.indices.contains(selectedIndex) ? results[selectedIndex] : nil
    }

    public func load() async {
        entries = await actions.searchableEntries()
        refresh()
    }

    private func refresh() {
        let ranked = query.isEmpty ? entries.sorted { $0.date > $1.date } : EntrySearch.search(query, in: entries)
        results = Array(ranked.prefix(Self.maximumResults))
    }

    public func boardName(of entry: Entry) -> String { actions.boardName(of: entry) }

    public func moveSelection(by offset: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = (selectedIndex + offset + results.count) % results.count
    }

    public func select(_ entry: Entry) {
        selectedIndex = results.firstIndex(of: entry) ?? selectedIndex
    }

    public func showSelected() {
        guard let entry = selected else { return }
        actions.closeQuickSearch()
        actions.show(entry)
    }

    public func openSelectedLink() {
        guard let link = selected?.link, !link.isEmpty else { return }
        actions.closeQuickSearch()
        actions.openLink(link)
    }

    public func close() {
        actions.closeQuickSearch()
    }
}
