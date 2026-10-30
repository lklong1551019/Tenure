import Foundation

/// One stretch of a career, usually one company: "Company A", July 2017 to August 2019.
public struct Board: LedgerItem, Hashable {
    public let id: UUID
    public var name: String
    public var start: YearMonth
    /// Nil while it is still the current one.
    public var end: YearMonth?
    public var createdAt: Timestamp
    public var updatedAt: Timestamp
    public var deletedAt: Timestamp?

    public init(
        id: UUID = UUID(),
        name: String,
        start: YearMonth,
        end: YearMonth? = nil,
        createdAt: Timestamp,
        updatedAt: Timestamp? = nil,
        deletedAt: Timestamp? = nil
    ) {
        self.id = id
        self.name = name
        self.start = start
        self.end = end
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.deletedAt = deletedAt
    }

    public var isCurrent: Bool {
        end == nil
    }

    /// Newest stretch first; the current one before any that ended.
    public static func timelineOrder(_ lhs: Board, _ rhs: Board) -> Bool {
        if lhs.start != rhs.start { return lhs.start > rhs.start }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, start, end, createdAt, updatedAt, deletedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        updatedAt = try container.decode(Timestamp.self, forKey: .updatedAt)
        name = container.lenient(String.self, forKey: .name) ?? ""
        start = container.lenient(YearMonth.self, forKey: .start) ?? YearMonth(updatedAt.date)
        end = container.lenient(YearMonth.self, forKey: .end)
        createdAt = container.lenient(Timestamp.self, forKey: .createdAt) ?? updatedAt
        deletedAt = container.lenient(Timestamp.self, forKey: .deletedAt)
    }
}
