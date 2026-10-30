import CryptoKit
import Domain
import Foundation

/// PKCE (RFC 7636) and `state` for one sign-in attempt. The verifier never leaves this Mac
/// before the code exchange, so an intercepted authorization code is useless on its own.
struct PKCE: Sendable {
    let verifier: String
    let challenge: String
    let state: String

    init(random: any RandomPort) throws {
        verifier = try random.bytes(count: 32).base64URLEncoded
        challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
        state = try random.bytes(count: 16).base64URLEncoded
    }
}

/// The pure parts of the OAuth flow, kept apart from networking so tests can check them.
enum OAuthFlow {
    static func authorizationURL(config: GoogleOAuthConfig, pkce: PKCE) -> URL {
        var components = URLComponents(url: GoogleOAuthConfig.authorizationEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: GoogleOAuthConfig.scope),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: pkce.state),
            // A refresh token, so sync keeps working after the 1-hour access token expires.
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]
        return components.url!
    }

    /// The authorization code from the redirect. A wrong `state` means the redirect did not
    /// come from the sign-in this app started.
    static func code(from callback: URL, config: GoogleOAuthConfig, expectedState: String) throws -> String {
        guard callback.scheme == config.redirectScheme,
            let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems
        else { throw DriveSignInError.failed }
        let value = { (name: String) in items.first { $0.name == name }?.value }
        if value("error") == "access_denied" { throw DriveSignInError.cancelled }
        guard value("state") == expectedState, let code = value("code"), !code.isEmpty else {
            throw DriveSignInError.failed
        }
        return code
    }

    static func exchangeRequest(code: String, pkce: PKCE, config: GoogleOAuthConfig) -> URLRequest {
        formRequest([
            ("grant_type", "authorization_code"),
            ("code", code),
            ("code_verifier", pkce.verifier),
            ("client_id", config.clientId),
            ("redirect_uri", config.redirectURI),
        ])
    }

    static func refreshRequest(refreshToken: String, config: GoogleOAuthConfig) -> URLRequest {
        formRequest([
            ("grant_type", "refresh_token"),
            ("refresh_token", refreshToken),
            ("client_id", config.clientId),
        ])
    }

    static func revocationRequest(token: String) -> URLRequest {
        formRequest([("token", token)], to: GoogleOAuthConfig.revocationEndpoint)
    }

    private static func formRequest(
        _ fields: [(String, String)],
        to url: URL = GoogleOAuthConfig.tokenEndpoint
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(fields.map { "\($0)=\(formEscape($1))" }.joined(separator: "&").utf8)
        return request
    }

    private static func formEscape(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

/// Google's token endpoint reply. `refresh_token` comes only with the first exchange.
struct TokenResponse: Decodable, Sendable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

/// `{"error": "invalid_grant"}`: the refresh token was revoked or expired.
struct TokenErrorResponse: Decodable {
    let error: String
}

extension Data {
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
