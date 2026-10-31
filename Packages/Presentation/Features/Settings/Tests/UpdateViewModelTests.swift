import Domain
import Foundation
import Testing

@testable import SettingsFeature

@MainActor
final class FakeUpdateActions: UpdateActions {
    var releases: [Release] = []
    var fails = false
    var fetches = 0
    var copied: [String] = []

    func fetchReleases() async throws -> [Release] {
        fetches += 1
        if fails { throw URLError(.notConnectedToInternet) }
        return releases
    }

    func openReleasePage() {}

    func copyText(_ text: String) {
        copied.append(text)
    }
}

@MainActor
@Suite("UpdateViewModel")
struct UpdateViewModelTests {
    let actions = FakeUpdateActions()
    let defaults: UserDefaults = {
        let name = "UpdateViewModelTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: name)!
    }()

    func model() -> UpdateViewModel {
        UpdateViewModel(currentVersion: "26.10.01", actions: actions, defaults: defaults)
    }

    @Test func manualCheckShowsNewerReleasesOrUpToDate() async {
        let model = model()
        actions.releases = [Release(version: "26.10.01"), Release(version: "26.11.01", new: ["Export"])]
        await model.check()
        #expect(model.latest?.version == "26.11.01")
        #expect(model.state == .available([Release(version: "26.11.01", new: ["Export"])]))

        actions.releases = [Release(version: "26.10.01")]
        await model.check()
        #expect(model.state == .upToDate)

        actions.fails = true
        await model.check()
        if case .failed = model.state {} else { Issue.record("expected a failure, got \(model.state)") }
    }

    @Test func backgroundCheckAsksForTheWindowUntilItShowsTheVersion() async {
        let model = model()
        actions.releases = [Release(version: "26.11.01")]
        await model.checkInBackground()
        #expect(model.windowRequests == 1)
        // The window did not show (no main window open): ask again next time.
        await model.checkInBackground()
        #expect(model.windowRequests == 2)
        model.markAnnounced()
        await model.checkInBackground()
        #expect(model.windowRequests == 2)
        actions.releases.append(Release(version: "26.11.02"))
        await model.checkInBackground()
        #expect(model.windowRequests == 3)
    }

    @Test func failedBackgroundCheckKeepsTheStateAndRetriesInAnHour() async {
        let model = model()
        actions.releases = [Release(version: "26.11.01")]
        await model.check()
        actions.fails = true
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        await model.checkInBackground(now: now)
        #expect(model.latest?.version == "26.11.01")
        #expect(model.secondsUntilNextCheck(now: now) == UpdateViewModel.retryInterval)
    }

    @Test func backgroundCheckRespectsTheSetting() async {
        let model = model()
        model.checksAutomatically = false
        actions.releases = [Release(version: "26.11.01")]
        await model.checkInBackground()
        #expect(actions.fetches == 0)
        #expect(UpdateViewModel(currentVersion: "1", actions: actions, defaults: defaults).checksAutomatically == false)
        #expect(model.secondsUntilNextCheck() == UpdateViewModel.interval)
    }

    @Test func nextCheckWaitsOutTwelveHours() async {
        let model = model()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(model.secondsUntilNextCheck(now: now) == UpdateViewModel.launchDelay)
        await model.checkInBackground(now: now)
        let later = now.addingTimeInterval(2 * 60 * 60)
        #expect(model.secondsUntilNextCheck(now: later) == 10 * 60 * 60)
        #expect(model.secondsUntilNextCheck(now: now.addingTimeInterval(13 * 60 * 60)) == UpdateViewModel.launchDelay)
    }

    @Test func copiesTheInstallCommand() {
        model().copyInstallCommand()
        #expect(actions.copied == [UpdateViewModel.installCommand])
    }
}
