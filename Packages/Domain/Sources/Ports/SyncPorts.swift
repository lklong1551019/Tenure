import Foundation

/// The data file in cloud storage. Bytes crossing this port are `tenure.json` as written
/// locally. Throws `RemoteStoreError`.
public protocol RemoteStorePort: Sendable {
    /// The newest revision, without downloading; nil when no remote copy exists yet.
    func head() async throws -> RemoteRevision?
    func download(_ revision: RemoteRevision) async throws -> Data
    /// Replaces the remote content. `pin` keeps this revision as a long-term backup.
    func upload(_ data: Data, pin: Bool) async throws -> RemoteRevision
    /// Revisions newer than `revision`, oldest first, the head included. Lets sync notice an
    /// upload from another Mac that landed between its own download and upload.
    func revisions(after revision: RemoteRevision) async throws -> [RemoteRevision]
}

/// Per-Mac sync bookkeeping. Not part of the data file.
public protocol SyncStatePort: Sendable {
    func record() -> SyncRecord?
    func save(_ record: SyncRecord)
    /// On sign-out: the next account starts from a fresh download and merge.
    func clear()
}

/// Sign-in to the cloud account that holds the remote copy. The only permission asked for is
/// access to files the app itself creates; no profile, no email.
public protocol DriveAccountPort: Sendable {
    /// From stored credentials, without any network call or prompt.
    func isSignedIn() async -> Bool
    /// Shows the provider's sign-in page. Throws `DriveSignInError`.
    func signIn() async throws
    /// Revokes the grant with the provider (best effort) and forgets it on this Mac.
    func signOut() async
}
