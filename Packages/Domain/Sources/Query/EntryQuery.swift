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
        let terms = EntrySearch.terms(of: text)
        return
            entries
            .filter { entry in
                (boardId == nil || entry.boardId == boardId)
                    && (types.isEmpty || types.contains(entry.type))
                    && EntrySearch.matches(terms: terms, entry)
            }
            .sorted(by: order)
    }

    /// Dates first when sorting by date: the localized name comparison is the slow part, so it
    /// runs only to break a tie or when sorting by name.
    private func order(_ lhs: Entry, _ rhs: Entry) -> Bool {
        switch sort {
        case .newest where lhs.date != rhs.date: return lhs.date > rhs.date
        case .oldest where lhs.date != rhs.date: return lhs.date < rhs.date
        default: break
        }
        let byName = lhs.name.localizedStandardCompare(rhs.name)
        if byName != .orderedSame {
            return sort == .nameDescending ? byName == .orderedDescending : byName == .orderedAscending
        }
        // Stable tiebreak, so equal keys never swap places between refreshes.
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
