import AppKit
import BoardFeature
import Domain
import EntryEditorFeature
import Foundation
import Observation
import SearchFeature
import SettingsFeature

/// App state and the glue between features and the store. Features talk to it through their
/// `*Actions` protocols; it never hands them a port.
@MainActor
@Observable
final class AppModel {
    enum Phase {
        case launching
        case failed(String)
        case ready(BoardViewModel)
    }

    private(set) var phase: Phase = .launching
    var editor: EntryEditorViewModel?
    var quickSearch: QuickSearchViewModel?
    private(set) var settings: SettingsViewModel?

    @ObservationIgnored private(set) var dependencies: AppDependencies?
    @ObservationIgnored private var observeTask: Task<Void, Never>?
    @ObservationIgnored private var syncStatusTask: Task<Void, Never>?
    @ObservationIgnored private var updateTask: Task<Void, Never>?
    /// Software Update: the window's state and the 12-hour background check.
    @ObservationIgnored private(set) lazy var updates = UpdateViewModel(
        currentVersion: AboutInfo.load().version,
        actions: self
    )

    var board: BoardViewModel? {
        if case .ready(let board) = phase { return board }
        return nil
    }

    var isReady: Bool { board != nil }

    /// Opens the data file and starts following it. Runs once, from the main window.
    func start() async {
        guard dependencies == nil else { return }
        let dependencies: AppDependencies
        do {
            dependencies = try AppDependencies.live()
        } catch LedgerError.unsupportedFormatVersion {
            phase = .failed("Your data was saved by a newer version of Tenure. Update the app to open it.")
            return
        } catch {
            phase = .failed("Couldn't open your data file. It was left untouched.")
            return
        }
        self.dependencies = dependencies
        let board = BoardViewModel(actions: self)
        board.update(await dependencies.store.snapshot())
        phase = .ready(board)
        settings = SettingsViewModel(actions: self)
        let changes = await dependencies.store.changes()
        observeTask = Task { [weak board] in
            for await snapshot in changes {
                board?.update(snapshot)
            }
        }
        startUpdateChecks()
        await startSyncIfSignedIn()
    }

    /// Checks for a newer version shortly after launch if 12 hours have passed since the last
    /// check, then every 12 hours while the app runs.
    private func startUpdateChecks() {
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let wait = self?.updates.secondsUntilNextCheck() else { return }
                try? await Task.sleep(for: .seconds(wait))
                guard !Task.isCancelled else { return }
                await self?.updates.checkInBackground()
            }
        }
    }

    var requiredDependencies: AppDependencies {
        get throws {
            guard let dependencies else { throw LedgerError.notFound }
            return dependencies
        }
    }

    // MARK: Commands

    func newEntry() {
        board?.newEntry()
    }

    func newBoard() {
        board?.newBoard()
    }

    func toggleQuickSearch() {
        quickSearch = quickSearch == nil && isReady ? QuickSearchViewModel(actions: self) : nil
    }

    /// After a change: the board shows it at once, and sync uploads it after a short pause.
    private func changed() async {
        guard let dependencies else { return }
        board?.update(await dependencies.store.snapshot())
        await dependencies.sync.localChange()
    }

    // MARK: Sync

    func startSyncIfSignedIn() async {
        guard let dependencies, dependencies.isSyncConfigured, await dependencies.driveAccount.isSignedIn() else {
            return
        }
        await dependencies.sync.start(dependencies.store)
        syncStatusTask?.cancel()
        let statuses = await dependencies.sync.statuses()
        syncStatusTask = Task { [weak self] in
            for await status in statuses {
                self?.board?.syncStatus = status
            }
        }
    }

    private func stopSync() async {
        syncStatusTask?.cancel()
        syncStatusTask = nil
        board?.syncStatus = nil
        await dependencies?.sync.stop()
    }
}

// MARK: - Board

extension AppModel: BoardActions {
    func saveBoard(_ board: Board) async throws {
        try await requiredDependencies.store.save(board)
        await changed()
    }

    func deleteBoard(_ board: Board) async throws {
        try await requiredDependencies.store.deleteBoard(board.id)
        await changed()
    }

    func deleteEntry(_ entry: Entry) async throws {
        try await requiredDependencies.store.deleteEntry(entry.id)
        await changed()
    }

    func editEntry(_ entry: Entry?, boardId: UUID?) {
        guard let board, !board.boards.isEmpty else { return }
        editor = EntryEditorViewModel(entry: entry, boardId: boardId, actions: self)
    }

    func openQuickSearch() {
        toggleQuickSearch()
    }

    func requestSync() {
        guard let dependencies else { return }
        Task { await dependencies.sync.syncNow() }
    }

    /// Opens a task's link, or a link inside its story, in the browser. Only http and https:
    /// the data can come from an imported or synced file, so a link must not reach another
    /// app's URL scheme or a file. A user name in the address ("company.com@evil.com") is
    /// refused too: it hides the real host.
    func openLink(_ link: String) {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: candidate), let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme), url.host() != nil, url.user() == nil, url.password() == nil
        else { return }
        NSWorkspace.shared.open(url)
    }

    func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func now() -> Timestamp {
        dependencies?.clock.now() ?? Timestamp(Date())
    }
}

// MARK: - Editor

extension AppModel: EntryEditorActions {
    var boards: [Board] {
        board?.boards ?? []
    }

    func saveEntry(_ entry: Entry) async throws {
        let saved = try await requiredDependencies.store.save(entry)
        await changed()
        board?.selectedEntryId = saved.id
    }

    func closeEditor() {
        editor = nil
    }
}

// MARK: - Quick search

extension AppModel: QuickSearchActions {
    func searchableEntries() async -> [Entry] {
        board?.liveEntries ?? []
    }

    func boardName(of entry: Entry) -> String {
        board?.boardName(of: entry) ?? ""
    }

    func show(_ entry: Entry) {
        board?.reveal(entry.id)
    }

    func closeQuickSearch() {
        quickSearch = nil
    }
}

// MARK: - Settings

extension AppModel: SettingsActions {
    var isSyncConfigured: Bool { dependencies?.isSyncConfigured ?? false }

    func isSignedInToDrive() async -> Bool {
        guard isSyncConfigured, let dependencies else { return false }
        return await dependencies.driveAccount.isSignedIn()
    }

    func signInToDrive() async throws {
        try await requiredDependencies.driveAccount.signIn()
        await startSyncIfSignedIn()
    }

    func signOutOfDrive() async {
        guard let dependencies else { return }
        await stopSync()
        await dependencies.driveAccount.signOut()
        dependencies.syncState.clear()
    }

    func syncNow() async {
        await dependencies?.sync.syncNow()
    }

    func syncStatuses() async -> AsyncStream<SyncStatus> {
        guard let dependencies else { return AsyncStream { $0.finish() } }
        return await dependencies.sync.statuses()
    }

    func revealDataFile() {
        guard let url = dependencies?.dataFileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func exportData() async throws -> Data {
        let dependencies = try requiredDependencies
        return try dependencies.codec.encode(await dependencies.store.snapshot())
    }

    func importData(_ data: Data) async throws -> Bool {
        let dependencies = try requiredDependencies
        let changed = try await dependencies.store.merge(try dependencies.codec.decode(data))
        if changed { await self.changed() }
        return changed
    }
}

extension AppModel: UpdateActions {
    func fetchReleases() async throws -> [Release] {
        try await requiredDependencies.releaseFeed.releases()
    }

    func openReleasePage() {
        NSWorkspace.shared.open(GitHubReleaseFeed.releasePage)
    }
}
