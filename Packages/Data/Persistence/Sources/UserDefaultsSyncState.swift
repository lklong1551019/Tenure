import Domain
import Foundation

/// Sync bookkeeping in UserDefaults: revision id, fingerprint, and dates. Nothing from inside
/// the ledger.
public struct UserDefaultsSyncState: SyncStatePort, @unchecked Sendable {
    // Invariant for @unchecked Sendable: UserDefaults is thread-safe.
    static let key = "syncRecord"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func record() -> SyncRecord? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        // An unreadable record only costs one full download on the next round.
        return try? JSONDecoder().decode(SyncRecord.self, from: data)
    }

    public func save(_ record: SyncRecord) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: Self.key)
    }

    public func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}
