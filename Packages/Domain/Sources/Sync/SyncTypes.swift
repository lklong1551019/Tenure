import Foundation

/// One version of the remote file. Opaque; compared for equality only.
public struct RemoteRevision: Sendable, Hashable, Codable {
    public let id: String

    public init(_ id: String) {
        self.id = id
    }
}

/// What this Mac last agreed on with the remote copy.
public struct SyncRecord: Sendable, Hashable, Codable {
    /// The remote revision whose content equals the local state at `syncedAt`.
    public let revision: RemoteRevision
    /// `SnapshotFingerprint` of that content: a different local fingerprint means local
    /// changes still to upload.
    public let fingerprint: UInt64
    public let syncedAt: Timestamp
    /// Day number (UTC) of the last pinned upload; the first upload of a new day is pinned.
    public let pinnedDay: Int64?

    public init(revision: RemoteRevision, fingerprint: UInt64, syncedAt: Timestamp, pinnedDay: Int64?) {
        self.revision = revision
        self.fingerprint = fingerprint
        self.syncedAt = syncedAt
        self.pinnedDay = pinnedDay
    }
}

/// Failures of the cloud transport. The local data is never affected.
public enum RemoteStoreError: Error, Sendable, Equatable {
    /// No account, or sign-in was revoked or expired: the user has to sign in again.
    case signedOut
    case offline
    case rateLimited
    case server(status: Int)
    case notFound
}

/// Why a sync round stopped. Nothing local changes when one is thrown.
public enum SyncError: Error, Sendable, Equatable {
    /// The remote file was written by a newer build.
    case unsupportedRemote(version: Int)
    /// The remote file does not decode, or carries stamps far in the future.
    case corruptRemote
    /// Another Mac kept uploading during every attempt; the next round retries.
    case busy
    /// The merged ledger could not be written to this Mac's disk.
    case localWriteFailed
    case remote(RemoteStoreError)
}

public enum SyncOutcome: Sendable, Equatable {
    /// Local and remote already held the same content.
    case upToDate
    /// Remote changes were merged in; nothing new to upload.
    case pulled
    /// Local changes (merged with any remote ones) were uploaded.
    case pushed
}

public enum SyncStatus: Sendable, Equatable {
    case idle
    case syncing
    case synced(at: Timestamp)
    case failed(SyncError, at: Timestamp)
}

/// Stable 64-bit FNV-1a over item stamps. Every content change moves an item's `updatedAt`
/// (`LedgerStore` stamps each save), so equal fingerprints mean equal content. `Hasher` is
/// seeded per process and cannot be persisted.
public enum SnapshotFingerprint {
    public static func of(_ snapshot: LedgerSnapshot) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        func mix(_ text: String) {
            for byte in text.utf8 {
                hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01b3
            }
        }
        for board in snapshot.boards.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            mix("|b|\(board.id.uuidString)|\(board.updatedAt.millis)|\(board.isDeleted)")
        }
        for entry in snapshot.entries.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            mix("|e|\(entry.id.uuidString)|\(entry.updatedAt.millis)|\(entry.isDeleted)")
        }
        return hash
    }
}

public enum DriveSignInError: Error, Sendable, Equatable {
    /// The user closed the sign-in page.
    case cancelled
    /// This build has no OAuth client configured (`Config/Secrets.xcconfig`).
    case notConfigured
    /// The provider refused the grant, or the reply did not check out.
    case failed
    case offline
}
