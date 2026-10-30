import Domain
import Foundation

/// Gives Drive requests an access token.
protocol AccessTokenProviding: Sendable {
    /// Throws `RemoteStoreError.signedOut` when there is no usable grant.
    func accessToken() async throws -> String
    /// After a 401: the cached token is no longer accepted.
    func invalidateAccessToken() async
}

/// Google sign-in with PKCE and the system sign-in sheet. The refresh token sits in the
/// Keychain; the access token (1 hour) only in memory. Neither is logged, stored in the ledger,
/// or written to a file.
public actor GoogleAuth: DriveAccountPort, AccessTokenProviding {
    /// Refreshed this long before Google's expiry, so a request never starts with a token
    /// about to lapse.
    static let refreshMargin: TimeInterval = 60

    private let config: GoogleOAuthConfig?
    private let store: any RefreshTokenStore
    private let web: any WebAuthenticating
    private let transport: HTTPTransport
    private let random: any RandomPort
    private let now: @Sendable () -> Date
    private var access: (token: String, expiresAt: Date)?
    /// One refresh at a time; concurrent requests wait for the same one.
    private var refreshing: Task<String, any Error>?

    /// `config` is nil when this build has no OAuth client; every call then reports that.
    public init(config: GoogleOAuthConfig?, random: any RandomPort, session: URLSession = .shared) {
        self.init(
            config: config,
            store: KeychainRefreshTokenStore(),
            web: SystemWebAuthenticator(),
            transport: HTTPTransport(session: session),
            random: random,
            now: { Date() }
        )
    }

    init(
        config: GoogleOAuthConfig?,
        store: any RefreshTokenStore,
        web: any WebAuthenticating,
        transport: HTTPTransport,
        random: any RandomPort,
        now: @escaping @Sendable () -> Date
    ) {
        self.config = config
        self.store = store
        self.web = web
        self.transport = transport
        self.random = random
        self.now = now
    }

    public func isSignedIn() -> Bool {
        config != nil && store.load() != nil
    }

    public func signIn() async throws {
        guard let config else { throw DriveSignInError.notConfigured }
        let pkce: PKCE
        do {
            pkce = try PKCE(random: random)
        } catch {
            throw DriveSignInError.failed
        }
        let callback = try await web.authenticate(
            url: OAuthFlow.authorizationURL(config: config, pkce: pkce),
            callbackScheme: config.redirectScheme
        )
        let code = try OAuthFlow.code(from: callback, config: config, expectedState: pkce.state)
        let response: TokenResponse
        do {
            response = try await token(
                OAuthFlow.exchangeRequest(code: code, pkce: pkce, config: config),
                idempotent: false
            )
        } catch RemoteStoreError.offline {
            throw DriveSignInError.offline
        } catch {
            throw DriveSignInError.failed
        }
        guard let refreshToken = response.refreshToken else { throw DriveSignInError.failed }
        try store.save(refreshToken)
        access = (response.accessToken, expiry(of: response))
    }

    public func signOut() async {
        let refreshToken = store.load()
        store.delete()
        access = nil
        refreshing?.cancel()
        refreshing = nil
        // Best effort: the grant is already gone from this Mac either way.
        if let refreshToken {
            _ = try? await transport.send(OAuthFlow.revocationRequest(token: refreshToken))
        }
    }

    func accessToken() async throws -> String {
        if let access, access.expiresAt > now().addingTimeInterval(Self.refreshMargin) {
            return access.token
        }
        if let refreshing {
            return try await refreshing.value
        }
        guard let config, let refreshToken = store.load() else { throw RemoteStoreError.signedOut }
        let task = Task { try await self.refresh(refreshToken, config: config) }
        refreshing = task
        defer { refreshing = nil }
        return try await task.value
    }

    func invalidateAccessToken() {
        access = nil
    }

    // MARK: Private

    private func refresh(_ refreshToken: String, config: GoogleOAuthConfig) async throws -> String {
        do {
            let response = try await token(OAuthFlow.refreshRequest(refreshToken: refreshToken, config: config))
            access = (response.accessToken, expiry(of: response))
            return response.accessToken
        } catch RemoteStoreError.signedOut {
            // Revoked in the Google account, or expired: only a new sign-in helps. A sign-in
            // that finished meanwhile stored a new token; that one stays.
            if store.load() == refreshToken {
                store.delete()
            }
            throw RemoteStoreError.signedOut
        }
    }

    /// Posts to the token endpoint. Only `invalid_grant` means the grant itself is gone; any
    /// other refusal (a misconfigured client, a bad request) keeps the stored token.
    private func token(_ request: URLRequest, idempotent: Bool = true) async throws -> TokenResponse {
        let (data, response) = try await transport.send(request, idempotent: idempotent)
        if response.statusCode == 400 || response.statusCode == 401 {
            let reply = try? JSONDecoder().decode(TokenErrorResponse.self, from: data)
            throw reply?.error == "invalid_grant"
                ? RemoteStoreError.signedOut : RemoteStoreError.server(status: response.statusCode)
        }
        try HTTPTransport.check(response, body: data)
        guard let decoded = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            throw RemoteStoreError.server(status: response.statusCode)
        }
        return decoded
    }

    private func expiry(of response: TokenResponse) -> Date {
        now().addingTimeInterval(TimeInterval(response.expiresIn))
    }
}
