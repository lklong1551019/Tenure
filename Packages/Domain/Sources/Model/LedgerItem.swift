import Foundation

/// What sync and merge need from a board or an entry. A delete keeps the item as a tombstone
/// (`deletedAt` set, `updatedAt` moved to the delete), so it reaches other Macs before it is
/// purged.
public protocol LedgerItem: Sendable, Codable, Identifiable where ID == UUID {
    var id: UUID { get }
    var updatedAt: Timestamp { get set }
    var deletedAt: Timestamp? { get set }
}

extension LedgerItem {
    public var isDeleted: Bool {
        deletedAt != nil
    }
}

extension KeyedDecodingContainer {
    /// A missing or malformed value becomes nil instead of failing the item: a value an older
    /// or newer build wrote must never make the whole file unreadable.
    func lenient<Value: Decodable>(_ type: Value.Type, forKey key: Key) -> Value? {
        (try? decodeIfPresent(type, forKey: key)) ?? nil
    }
}
