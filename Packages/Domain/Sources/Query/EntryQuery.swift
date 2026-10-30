import Foundation

public enum EntrySort: String, Sendable, CaseIterable, Codable {
    case newest
    case oldest
    case nameAscending
    case nameDescending
}

/// What the board shows: which board, which kinds, a text filter, and an order. Pure, so the
/// view model only holds the settings.
public struct EntryQuery: Sendable, Hashable {
    /// Nil shows every board.
    public var boardId: UUID?
    /// Empty shows every kind, including kinds this build does not know.
    public var types: Set<EntryType>
    public var text: String
    public var sort: EntrySort

    public init(boardId: UUID? = nil, types: Set<EntryType> = [], text: String = "", sort: EntrySort = .newest) {
        self.boardId = boardId
        self.types = types
        self.text = text
        self.sort = sort
    }

    public func apply(to entries: [Entry]) -> [Entry] {
        entries
            .filter { entry in
                (boardId == nil || entry.boardId == boardId)
                    && (types.isEmpty || types.contains(entry.type))
                    && EntrySearch.matches(text, entry)
            }
            .sorted(by: order)
    }

    private func order(_ lhs: Entry, _ rhs: Entry) -> Bool {
        let byName = lhs.name.localizedStandardCompare(rhs.name)
        switch sort {
        case .newest:
            if lhs.date != rhs.date { return lhs.date > rhs.date }
        case .oldest:
            if lhs.date != rhs.date { return lhs.date < rhs.date }
        case .nameAscending:
            if byName != .orderedSame { return byName == .orderedAscending }
        case .nameDescending:
            if byName != .orderedSame { return byName == .orderedDescending }
        }
        // Stable tiebreak, so equal keys never swap places between refreshes.
        if byName != .orderedSame { return byName == .orderedAscending }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
