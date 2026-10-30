import Domain
import DriveSync
import Foundation
import Persistence

/// Composition root: the only place that knows which implementation backs each port.
struct AppDependencies {
    let store: LedgerStore
    let dataFileURL: URL
    let codec: any LedgerCodecPort
    let clock: any ClockPort
    /// False for a build without `Config/Secrets.xcconfig`: no sign-in, no sync.
    let isSyncConfigured: Bool
    let driveAccount: any DriveAccountPort
    let syncState: any SyncStatePort
    /// The one scheduler: started on launch and after sign-in, stopped on sign-out.
    let sync: SyncScheduler

    static func live() throws -> AppDependencies {
        let clock = SystemClock()
        let fileURL = try FileLedgerRepository.defaultFileURL()
        let codec = LedgerFileCodec()
        let store = try LedgerStore(repository: FileLedgerRepository(fileURL: fileURL, codec: codec), clock: clock)
        let config = GoogleOAuthConfig(
            clientId: Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String ?? "",
            redirectScheme: Bundle.main.object(forInfoDictionaryKey: "GoogleRedirectScheme") as? String ?? ""
        )
        let auth = GoogleAuth(config: config, random: SystemRandom())
        let remote = DriveClient(
            auth: auth,
            namespace: Bundle.main.object(forInfoDictionaryKey: "DriveNamespace") as? String ?? ""
        )
        let syncState = UserDefaultsSyncState()
        let syncLedger = SyncLedger(remote: remote, codec: codec, state: syncState, clock: clock)
        return AppDependencies(
            store: store,
            dataFileURL: fileURL,
            codec: codec,
            clock: clock,
            isSyncConfigured: config != nil,
            driveAccount: auth,
            syncState: syncState,
            sync: SyncScheduler(sync: syncLedger, clock: clock)
        )
    }
}
