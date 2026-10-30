import Foundation

/// Rules every remote copy passes before anything local changes. The remote file is
/// untrusted input: it can be edited by hand or written by a newer build.
enum RemoteLedgerCheck {
    static func decode(_ data: Data, codec: any LedgerCodecPort) throws -> LedgerSnapshot {
        do {
            return try codec.decode(data)
        } catch LedgerError.unsupportedFormatVersion(let version) {
            throw SyncError.unsupportedRemote(version: version)
        } catch {
            throw SyncError.corruptRemote
        }
    }

    /// Clock skew tolerated between Macs. A stamp further ahead would win every merge for as
    /// long as it stays in the future, so a remote copy carrying one is refused.
    static let maximumSkewDays = 1

    static func rejectFutureStamps(in snapshot: LedgerSnapshot, now: Timestamp) throws {
        let limit = now.adding(days: maximumSkewDays)
        guard snapshot.boards.allSatisfy({ $0.updatedAt <= limit }),
            snapshot.entries.allSatisfy({ $0.updatedAt <= limit })
        else {
            throw SyncError.corruptRemote
        }
    }

    /// Transport errors become `SyncError.remote`; anything local (a failed file write)
    /// becomes `.localWriteFailed`.
    static func mapping<Value>(_ body: () async throws -> Value) async throws -> Value {
        do {
            return try await body()
        } catch let error as SyncError {
            throw error
        } catch let error as RemoteStoreError {
            throw SyncError.remote(error)
        } catch {
            throw SyncError.localWriteFailed
        }
    }
}
