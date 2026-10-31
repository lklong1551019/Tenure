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
/// Check for Updates, Settings > About), and in the background every 12 hours, or an hour after
/// a failed attempt. A background check asks for the window until the window has shown that
/// version once.
@MainActor
@Observable
public final class UpdateViewModel {
    static let interval: TimeInterval = 12 * 60 * 60
    /// After a failed background check (offline, GitHub down), try again this much later.
    static let retryInterval: TimeInterval = 60 * 60
    /// Wait after launch before the first background check, so it never slows startup.
    static let launchDelay: TimeInterval = 30
    public static let installCommand = "git pull && scripts/install-app.sh"

    static let automaticKey = "checksForUpdates"
    /// When the last background attempt ran, and whether it failed.
    static let lastCheckKey = "lastUpdateCheck"
    static let lastCheckFailedKey = "lastUpdateCheckFailed"
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

    /// From the menu or the button: always shows the outcome. A check already running is not
    /// started twice (the menu item and the window's first appearance can both ask).
    public func check() async {
        guard state != .checking else { return }
        state = .checking
        do {
            state = outcome(of: try await actions.fetchReleases())
        } catch {
            state = .failed("Couldn't reach GitHub. Check the connection and try again.")
        }
    }

    /// From the timer: quiet unless there is a version the window has not shown yet. A failure
    /// keeps whatever the window showed before.
    public func checkInBackground(now: Date = Date()) async {
        guard checksAutomatically, state != .checking else { return }
        defaults.set(now, forKey: Self.lastCheckKey)
        do {
            state = outcome(of: try await actions.fetchReleases())
            defaults.set(false, forKey: Self.lastCheckFailedKey)
        } catch {
            defaults.set(true, forKey: Self.lastCheckFailedKey)
            return
        }
        if let latest, latest.version != defaults.string(forKey: Self.announcedKey) {
            windowRequests += 1
        }
    }

    /// Called when the window shows: its newest version now counts as announced.
    public func markAnnounced() {
        guard let latest else { return }
        defaults.set(latest.version, forKey: Self.announcedKey)
    }

    /// Seconds until the next background check: 12 hours after the last attempt, an hour after
    /// a failed one, a full interval while automatic checks are off, and never sooner than the
    /// launch delay.
    public func secondsUntilNextCheck(now: Date = Date()) -> TimeInterval {
        guard checksAutomatically else { return Self.interval }
        let last = defaults.object(forKey: Self.lastCheckKey) as? Date ?? .distantPast
        let wait = defaults.bool(forKey: Self.lastCheckFailedKey) ? Self.retryInterval : Self.interval
        return max(wait - now.timeIntervalSince(last), Self.launchDelay)
    }

    public func openReleasePage() {
        actions.openReleasePage()
    }

    public func copyInstallCommand() {
        actions.copyText(Self.installCommand)
    }

    private func outcome(of releases: [Release]) -> UpdateState {
        let newer = UpdateCheck.newer(than: currentVersion, in: releases)
        return newer.isEmpty ? .upToDate : .available(newer)
    }
}
