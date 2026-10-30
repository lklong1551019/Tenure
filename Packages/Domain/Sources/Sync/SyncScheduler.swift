import Foundation

/// Decides when `SyncLedger` runs: right away on start, every 15 minutes, 5 seconds after
/// the last local change, and on "Sync now". Only while started (signed in), and never two
/// rounds at once: a request during a round runs one more round after it.
public actor SyncScheduler {
    public static let debounce: Duration = .seconds(5)
    public static let interval: Duration = .seconds(15 * 60)

    private let sync: @Sendable (LedgerStore) async throws -> SyncOutcome
    private let clock: any ClockPort
    private let debounce: Duration
    private let interval: Duration
    private var store: LedgerStore?
    private var periodicTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var isRunning = false
    private var runAgain = false
    private var status: SyncStatus = .idle
    private var observers: [UUID: AsyncStream<SyncStatus>.Continuation] = [:]

    public init(
        sync: SyncLedger,
        clock: any ClockPort = SystemClock(),
        debounce: Duration = SyncScheduler.debounce,
        interval: Duration = SyncScheduler.interval
    ) {
        self.init(sync: { try await sync($0) }, clock: clock, debounce: debounce, interval: interval)
    }

    init(
        sync: @escaping @Sendable (LedgerStore) async throws -> SyncOutcome,
        clock: any ClockPort,
        debounce: Duration,
        interval: Duration
    ) {
        self.sync = sync
        self.clock = clock
        self.debounce = debounce
        self.interval = interval
    }

    /// On launch when signed in, and right after sign-in: syncs now, then every `interval`.
    public func start(_ store: LedgerStore) {
        stop()
        self.store = store
        periodicTask = Task { [interval] in
            while !Task.isCancelled {
                await self.run()
                try? await Task.sleep(for: interval)
            }
        }
    }

    /// On sign-out. A round in flight finishes on its own.
    public func stop() {
        periodicTask?.cancel()
        debounceTask?.cancel()
        periodicTask = nil
        debounceTask = nil
        store = nil
        publish(.idle)
    }

    /// After every local save; bursts of edits collapse into one round.
    public func localChange() {
        guard store != nil else { return }
        debounceTask?.cancel()
        debounceTask = Task { [debounce] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            await self.run()
        }
    }

    public func syncNow() async {
        await run()
    }

    /// Yields the current status first, then every change.
    public func statuses() -> AsyncStream<SyncStatus> {
        let (stream, continuation) = AsyncStream<SyncStatus>.makeStream()
        let id = UUID()
        observers[id] = continuation
        continuation.yield(status)
        continuation.onTermination = { _ in Task { await self.removeObserver(id) } }
        return stream
    }

    // MARK: Private

    private func run() async {
        guard let store else { return }
        guard !isRunning else {
            runAgain = true
            return
        }
        isRunning = true
        defer { isRunning = false }
        repeat {
            runAgain = false
            publish(.syncing)
            do {
                _ = try await sync(store)
                publish(.synced(at: clock.now()))
            } catch let error as SyncError {
                publish(.failed(error, at: clock.now()))
            } catch {
                publish(.failed(.localWriteFailed, at: clock.now()))
            }
        } while runAgain && self.store === store
    }

    private func publish(_ newStatus: SyncStatus) {
        status = newStatus
        for continuation in observers.values {
            continuation.yield(newStatus)
        }
    }

    private func removeObserver(_ id: UUID) {
        observers[id] = nil
    }
}
