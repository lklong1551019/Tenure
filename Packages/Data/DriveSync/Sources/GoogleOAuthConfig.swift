import Foundation

/// The app's OAuth client: an iOS-type client from the owner's Google Cloud project. It is a
/// public client: there is no client secret, and PKCE protects the code exchange instead.
public struct GoogleOAuthConfig: Sendable, Equatable {
    static let authorizationEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    static let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
    static let revocationEndpoint = URL(string: "https://oauth2.googleapis.com/revoke")!
    /// Files this app creates, nothing else in the Drive; no profile or email scope.
    static let scope = "https://www.googleapis.com/auth/drive.file"

    public let clientId: String
    /// The reversed client id (`com.googleusercontent.apps.<id>`), which Google accepts as a
    /// redirect scheme for iOS-type clients.
    public let redirectScheme: String

    /// Nil for a build without a configured client (placeholder or empty values).
    public init?(clientId: String, redirectScheme: String) {
        let id = clientId.trimmingCharacters(in: .whitespaces)
        let scheme = redirectScheme.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty, !scheme.isEmpty, id != "temp", scheme != "temp", !id.hasPrefix("$(") else {
            return nil
        }
        self.clientId = id
        self.redirectScheme = scheme
    }

    var redirectURI: String { "\(redirectScheme):/oauth2redirect" }
}
