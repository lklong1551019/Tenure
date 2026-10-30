import Domain
import Foundation
import Observation

/// What the update window needs from the app.
@MainActor
public protocol UpdateActions: AnyObject {
    /// Every published release, newest first.
    func fetchReleases() async throws -> [Release]
    func openReleasePage()
    func copyText(_ text: String)
}

public enum UpdateState: Equatable, Sendable {
    case idle
    case checking
    case upToDate
    /// Newer releases, newest first.
    case available([Release])
    case failed(String)
}

/// Checks the published changelog for versions newer than this build: on request (Tenure >
/// Check for Updates, Settings > About), and in the background every 12 hours. A background
/// check opens the window only for a version it has not announced before.
@MainActor
@Observable
public final class UpdateViewModel {
    public static let interval: TimeInterval = 12 * 60 * 60
    /// Wait after launch before the first background check, so it never slows startup.
    static let launchDelay: TimeInterval = 30
    public static let installCommand = "git pull && scripts/install-app.sh"

    static let automaticKey = "checksForUpdates"
    static let lastCheckKey = "lastUpdateCheck"
    static let announcedKey = "announcedVersion"

    public let currentVersion: String
    public private(set) var state = UpdateState.idle
    /// Bumped when a background check finds something new; the app opens the window on change.
    public private(set) var windowRequests = 0
    public var checksAutomatically: Bool {
        didSet { defaults.set(checksAutomatically, forKey: Self.automaticKey) }
    }

    private let actions: any UpdateActions
    private let defaults: UserDefaults

    public init(currentVersion: String, actions: any UpdateActions, defaults: UserDefaults = .standard) {
        self.currentVersion = currentVersion
        self.actions = actions
        self.defaults = defaults
        checksAutomatically = defaults.object(forKey: Self.automaticKey) as? Bool ?? true
    }

    /// The newest release, when one is available.
    public var latest: Release? {
        if case .available(let releases) = state { return releases.first }
        return nil
    }

    /// From the menu or the button: always shows the outcome.
    public func check() async {
        state = .checking
        await run()
    }

    /// From the 12-hour timer: quiet unless there is a version not announced before.
    public func checkInBackground(now: Date = Date()) async {
        guard checksAutomatically, state != .checking else { return }
        await run(now: now)
        guard let latest, latest.version != defaults.string(forKey: Self.announcedKey) else { return }
        defaults.set(latest.version, forKey: Self.announcedKey)
        windowRequests += 1
    }

    /// Seconds until the next background check is due: the rest of the 12 hours since the
    /// last one, but never sooner than the launch delay.
    public func secondsUntilNextCheck(now: Date = Date()) -> TimeInterval {
        let last = defaults.object(forKey: Self.lastCheckKey) as? Date ?? .distantPast
        return max(Self.interval - now.timeIntervalSince(last), Self.launchDelay)
    }

    public func openReleasePage() {
        actions.openReleasePage()
    }

    public func copyInstallCommand() {
        actions.copyText(Self.installCommand)
    }

    private func run(now: Date = Date()) async {
        do {
            let releases = try await actions.fetchReleases()
            defaults.set(now, forKey: Self.lastCheckKey)
            let newer = UpdateCheck.newer(than: currentVersion, in: releases)
            state = newer.isEmpty ? .upToDate : .available(newer)
        } catch {
            state = .failed("Couldn't reach GitHub. Check the connection and try again.")
        }
    }
}
