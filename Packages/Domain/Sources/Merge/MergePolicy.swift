import Foundation

/// Merges two copies of the ledger. Per item, last-writer-wins on `updatedAt`; ties resolve
/// the same way on every Mac, so two Macs that merge each other's copies converge.
public enum MergePolicy {
    /// Long enough for a Mac that has been offline for a while to receive the delete before
    /// the tombstone disappears and the old copy could come back.
    public static let tombstoneRetentionDays = 90

    public static func merge(
        local: LedgerSnapshot,
        remote: LedgerSnapshot,
        now: Timestamp,
        retentionDays: Int = tombstoneRetentionDays
    ) -> LedgerSnapshot {
        LedgerSnapshot(
            boards: mergeItems(local: local.boards, remote: remote.boards, now: now, retentionDays: retentionDays),
            entries: mergeItems(local: local.entries, remote: remote.entries, now: now, retentionDays: retentionDays)
        )
    }

    public static func mergeItems<Item: LedgerItem>(
        local: [Item],
        remote: [Item],
        now: Timestamp,
        retentionDays: Int = tombstoneRetentionDays
    ) -> [Item] {
        var merged: [UUID: Item] = [:]
        for item in local + remote {
            merged[item.id] = merged[item.id].map { winner($0, item) } ?? item
        }
        let cutoff = now.adding(days: -retentionDays)
        return merged.values
            .filter { !($0.isDeleted && $0.updatedAt < cutoff) }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }

    static func winner<Item: LedgerItem>(_ lhs: Item, _ rhs: Item) -> Item {
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt ? lhs : rhs
        }
        // Same instant: a delete beats an edit, then the larger canonical encoding wins. Both
        // rules are symmetric, which is what makes merge order irrelevant.
        if lhs.isDeleted != rhs.isDeleted {
            return lhs.isDeleted ? lhs : rhs
        }
        return canonical(lhs).lexicographicallyPrecedes(canonical(rhs)) ? rhs : lhs
    }

    private static func canonical<Item: LedgerItem>(_ item: Item) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(item)) ?? Data()
    }
}
