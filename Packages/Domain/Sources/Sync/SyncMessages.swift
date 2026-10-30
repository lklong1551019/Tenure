import Foundation

extension SyncError {
    /// One line for the status row and the toolbar tooltip.
    public var message: String {
        switch self {
        case .unsupportedRemote:
            "The copy in Google Drive comes from a newer version of Tenure. Update this Mac to sync."
        case .corruptRemote:
            "The copy in Google Drive failed its checks and was not used. Data on this Mac is unchanged."
        case .busy:
            "Another Mac is syncing. Sync retries shortly."
        case .localWriteFailed:
            "Couldn't save the synced data on this Mac."
        case .remote(let error):
            error.message
        }
    }

    /// Needs the user to act (sign in again, update); retrying alone will not fix it.
    public var needsAttention: Bool {
        switch self {
        case .busy, .localWriteFailed: false
        case .unsupportedRemote, .corruptRemote: true
        case .remote(let error): error == .signedOut
        }
    }
}

extension RemoteStoreError {
    public var message: String {
        switch self {
        case .signedOut: "Google sign-in expired. Sign in again to keep syncing."
        case .offline: "Offline. Sync resumes when this Mac is back online."
        case .rateLimited: "Google Drive is busy. Sync retries shortly."
        case .server, .notFound: "Google Drive had a problem. Sync retries shortly."
        }
    }
}

extension DriveSignInError {
    /// Nil when nothing needs saying: the user closed the sign-in page.
    public var message: String? {
        switch self {
        case .cancelled: nil
        case .notConfigured: "Google Drive sync isn't set up in this build."
        case .failed: "Google sign-in didn't complete. Try again."
        case .offline: "Offline. Connect to the internet and try again."
        }
    }
}
