import Foundation

/// One thing done: a feature shipped, a bug fixed, a finding written up. Named `Entry`
/// rather than `Task`, which Swift concurrency already owns; the UI calls it a task.
public struct Entry: LedgerItem, Hashable {
    public let id: UUID
    public var boardId: UUID
    public var name: String
    /// Ticket or document link, kept as typed: it may not be a valid URL.
    public var link: String?
    public var type: EntryType
    public var date: DayDate
    /// Last day, for work that spanned a while; nil for a single day.
    public var endDate: DayDate?
    public var tags: [String]
    /// Markdown write-up, in the order a story is told.
    public var problem: String
    public var why: String
    public var solution: String
    public var impact: String
    public var difficulties: String
    public var metrics: [Metric]
    public var createdAt: Timestamp
    public var updatedAt: Timestamp
    public var deletedAt: Timestamp?

    public init(
        id: UUID = UUID(),
        boardId: UUID,
        name: String,
        link: String? = nil,
        type: EntryType = .dev,
        date: DayDate,
        endDate: DayDate? = nil,
        tags: [String] = [],
        problem: String = "",
        why: String = "",
        solution: String = "",
        impact: String = "",
        difficulties: String = "",
        metrics: [Metric] = [],
        createdAt: Timestamp,
        updatedAt: Timestamp? = nil,
        deletedAt: Timestamp? = nil
    ) {
        self.id = id
        self.boardId = boardId
        self.name = name
        self.link = link
        self.type = type
        self.date = date
        self.endDate = endDate
        self.tags = tags
        self.problem = problem
        self.why = why
        self.solution = solution
        self.impact = impact
        self.difficulties = difficulties
        self.metrics = metrics
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.deletedAt = deletedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, boardId, name, link, type, date, endDate, tags
        case problem, why, solution, impact, difficulties, metrics
        case createdAt, updatedAt, deletedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        boardId = try container.decode(UUID.self, forKey: .boardId)
        updatedAt = try container.decode(Timestamp.self, forKey: .updatedAt)
        name = container.lenient(String.self, forKey: .name) ?? ""
        link = container.lenient(String.self, forKey: .link)
        type = container.lenient(EntryType.self, forKey: .type) ?? .dev
        date = container.lenient(DayDate.self, forKey: .date) ?? DayDate(updatedAt.date)
        endDate = container.lenient(DayDate.self, forKey: .endDate)
        tags = container.lenient([String].self, forKey: .tags) ?? []
        problem = container.lenient(String.self, forKey: .problem) ?? ""
        why = container.lenient(String.self, forKey: .why) ?? ""
        solution = container.lenient(String.self, forKey: .solution) ?? ""
        impact = container.lenient(String.self, forKey: .impact) ?? ""
        difficulties = container.lenient(String.self, forKey: .difficulties) ?? ""
        metrics = container.lenient([Metric].self, forKey: .metrics) ?? []
        createdAt = container.lenient(Timestamp.self, forKey: .createdAt) ?? updatedAt
        deletedAt = container.lenient(Timestamp.self, forKey: .deletedAt)
    }
}

/// Kind of work. A raw string rather than a closed enum, so a kind written by a newer build
/// (or typed into the file by hand) survives a round trip through an older one.
public struct EntryType: RawRepresentable, Sendable, Hashable, Codable {
    public static let product = EntryType(rawValue: "product")
    public static let dev = EntryType(rawValue: "dev")
    public static let bugFix = EntryType(rawValue: "bugFix")
    public static let findings = EntryType(rawValue: "findings")
    public static let known: [EntryType] = [.product, .dev, .bugFix, .findings]

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// A number worth quoting later, such as cold start 1.8 s to 0.9 s. Values stay text: "p50",
/// "~40%", and "1.2k req/s" are all fine.
public struct Metric: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public var label: String
    public var before: String?
    public var after: String
    public var unit: String?
    /// How it was measured: device, sample size, time window.
    public var note: String?

    public init(
        id: UUID = UUID(),
        label: String,
        before: String? = nil,
        after: String,
        unit: String? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.label = label
        self.before = before
        self.after = after
        self.unit = unit
        self.note = note
    }

    private enum CodingKeys: String, CodingKey {
        case id, label, before, after, unit, note
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.lenient(UUID.self, forKey: .id) ?? UUID()
        label = container.lenient(String.self, forKey: .label) ?? ""
        before = container.lenient(String.self, forKey: .before)
        after = container.lenient(String.self, forKey: .after) ?? ""
        unit = container.lenient(String.self, forKey: .unit)
        note = container.lenient(String.self, forKey: .note)
    }
}

extension EntryType {
    /// "Bug fix" for the known kinds; an unknown kind shows as written.
    public var title: String {
        switch self {
        case .product: "Product"
        case .dev: "Dev"
        case .bugFix: "Bug fix"
        case .findings: "Findings"
        default: rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }
}
