import Foundation

/// One sync round between the local store and the remote copy:
///
/// 1. Remote head unchanged since the last round: upload only if local changed.
/// 2. Head changed: download, check, merge into the store (which saves locally), then upload
///    the merged state unless the remote already holds it.
/// 3. After uploading, list revisions since the downloaded head. One from another Mac that
///    landed in between was overwritten: merge it and upload again. Merging is idempotent, so
///    a few attempts converge.
///
/// Throws `SyncError`. A failed round leaves the local ledger as it was or with remote changes
/// fully merged, never half-applied.
public struct SyncLedger: Sendable {
    static let maxAttempts = 3

    private let remote: any RemoteStorePort
    private let codec: any LedgerCodecPort
    private let state: any SyncStatePort
    private let clock: any ClockPort

    public init(
        remote: any RemoteStorePort,
        codec: any LedgerCodecPort,
        state: any SyncStatePort,
        clock: any ClockPort = SystemClock()
    ) {
        self.remote = remote
        self.codec = codec
        self.state = state
        self.clock = clock
    }

    @discardableResult
    public func callAsFunction(_ store: LedgerStore) async throws -> SyncOutcome {
        try await RemoteLedgerCheck.mapping { try await round(store) }
    }

    // MARK: Private

    private func round(_ store: LedgerStore) async throws -> SyncOutcome {
        let record = state.record()
        guard var base = try await remote.head() else {
            return try await createRemote(from: store, record: record)
        }
        // Fingerprint of what `base` holds, when known without downloading it.
        var baseFingerprint = base == record?.revision ? record?.fingerprint : nil
        var pulled = false
        for _ in 0..<Self.maxAttempts {
            if baseFingerprint == nil {
                let (changed, fingerprint) = try await pull(base, into: store)
                pulled = pulled || changed
                baseFingerprint = fingerprint
            }
            let local = await store.snapshot()
            let fingerprint = SnapshotFingerprint.of(local)
            if fingerprint == baseFingerprint {
                remember(record, revision: base, fingerprint: fingerprint, pinned: false)
                return pulled ? .pulled : .upToDate
            }
            let pin = isFirstUploadToday(record)
            let uploaded = try await remote.upload(try codec.encode(local), pin: pin)
            let missed = try await remote.revisions(after: base).filter { $0 != uploaded }
            if missed.isEmpty {
                remember(record, revision: uploaded, fingerprint: fingerprint, pinned: pin)
                return .pushed
            }
            // Another Mac uploaded between this round's download and upload, and this upload
            // replaced its content: merge what it wrote, then upload again over this one.
            for revision in missed {
                _ = try await pull(revision, into: store)
            }
            base = uploaded
            baseFingerprint = fingerprint
        }
        throw SyncError.busy
    }

    /// No remote copy yet: the first upload creates it.
    private func createRemote(from store: LedgerStore, record: SyncRecord?) async throws -> SyncOutcome {
        let local = await store.snapshot()
        let uploaded = try await remote.upload(try codec.encode(local), pin: true)
        remember(record, revision: uploaded, fingerprint: SnapshotFingerprint.of(local), pinned: true)
        return .pushed
    }

    /// Downloads one revision and merges it into the store. Returns whether local state
    /// changed and the fingerprint of the downloaded content.
    private func pull(_ revision: RemoteRevision, into store: LedgerStore) async throws -> (Bool, UInt64) {
        let remoteSnapshot = try RemoteLedgerCheck.decode(try await remote.download(revision), codec: codec)
        try RemoteLedgerCheck.rejectFutureStamps(in: remoteSnapshot, now: clock.now())
        let changed = try await store.merge(remoteSnapshot)
        return (changed, SnapshotFingerprint.of(remoteSnapshot))
    }

    private func isFirstUploadToday(_ record: SyncRecord?) -> Bool {
        record?.pinnedDay != today
    }

    private var today: Int64 {
        clock.now().millis / Timestamp.millisPerDay
    }

    private func remember(_ previous: SyncRecord?, revision: RemoteRevision, fingerprint: UInt64, pinned: Bool) {
        state.save(
            SyncRecord(
                revision: revision,
                fingerprint: fingerprint,
                syncedAt: clock.now(),
                pinnedDay: pinned ? today : previous?.pinnedDay
            )
        )
    }
}
