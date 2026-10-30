import Domain
import Foundation
import Observation

/// What Settings needs from the app.
@MainActor
public protocol SettingsActions: AnyObject {
    /// False for a build without a Google OAuth client.
    var isSyncConfigured: Bool { get }
    func isSignedInToDrive() async -> Bool
    /// Throws `DriveSignInError`.
    func signInToDrive() async throws
    func signOutOfDrive() async
    func syncNow() async
    func syncStatuses() async -> AsyncStream<SyncStatus>
    func revealDataFile()
    /// The whole ledger as `tenure.json` bytes.
    func exportData() async throws -> Data
    /// Merges a `tenure.json` into the ledger. Returns whether anything changed.
    func importData(_ data: Data) async throws -> Bool
}

@MainActor
@Observable
public final class SettingsViewModel {
    public private(set) var isSignedIn = false
    public private(set) var status: SyncStatus = .idle
    public private(set) var isWorking = false
    /// From the last sign-in attempt; sync failures show through `status` instead.
    public private(set) var signInError: String?
    /// Result of the last export or import.
    public private(set) var dataMessage: String?
    public private(set) var dataMessageIsError = false

    private let actions: any SettingsActions

    public init(actions: any SettingsActions) {
        self.actions = actions
    }

    public var isConfigured: Bool { actions.isSyncConfigured }
    public var canSyncNow: Bool { isSignedIn && status != .syncing }

    public func load() async {
        isSignedIn = await actions.isSignedInToDrive()
    }

    /// Follows the scheduler for as long as the caller's task lives.
    public func observe() async {
        for await next in await actions.syncStatuses() {
            status = next
            // A revoked or expired grant was already forgotten by the auth layer.
            if case .failed(.remote(.signedOut), _) = next {
                isSignedIn = await actions.isSignedInToDrive()
            }
        }
    }

    public func signIn() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        signInError = nil
        do {
            try await actions.signInToDrive()
            isSignedIn = true
        } catch let error as DriveSignInError {
            signInError = error.message
        } catch {
            signInError = DriveSignInError.failed.message
        }
    }

    public func signOut() async {
        await actions.signOutOfDrive()
        isSignedIn = false
        status = .idle
    }

    public func syncNow() async {
        await actions.syncNow()
    }

    public func revealDataFile() {
        actions.revealDataFile()
    }

    public func exportData() async -> Data? {
        do {
            return try await actions.exportData()
        } catch {
            report("Couldn't export the data.", isError: true)
            return nil
        }
    }

    public func exported(_ result: Result<URL, any Error>) {
        switch result {
        case .success(let url): report("Exported to \(url.lastPathComponent).", isError: false)
        case .failure: report("Couldn't export the data.", isError: true)
        }
    }

    public func importFile(_ result: Result<URL, any Error>) async {
        guard case .success(let url) = result else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let changed = try await actions.importData(try Data(contentsOf: url))
            report(
                changed ? "Imported \(url.lastPathComponent)." : "Nothing new in \(url.lastPathComponent).",
                isError: false
            )
        } catch LedgerError.unsupportedFormatVersion {
            report("That file comes from a newer version of Tenure.", isError: true)
        } catch {
            report("That file isn't a Tenure export.", isError: true)
        }
    }

    /// One line for the status row.
    public func statusText(now: Date = Date()) -> String {
        switch status {
        case .idle:
            return "Not synced yet"
        case .syncing:
            return "Syncing..."
        case .synced(let at):
            return "Synced " + Self.describe(at.date, now: now)
        case .failed(let error, _):
            return error.message
        }
    }

    public var hasProblem: Bool {
        if case .failed = status { return true }
        return false
    }

    nonisolated static func describe(_ date: Date, now: Date) -> String {
        if now.timeIntervalSince(date) < 60 { return "just now" }
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        return calendar.isDate(date, inSameDayAs: now)
            ? "at \(time)" : "on \(date.formatted(date: .abbreviated, time: .omitted)), \(time)"
    }

    private func report(_ message: String, isError: Bool) {
        dataMessage = message
        dataMessageIsError = isError
    }
}
