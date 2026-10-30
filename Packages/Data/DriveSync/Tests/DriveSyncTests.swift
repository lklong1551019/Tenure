import CryptoKit
import Domain
import Foundation
import Testing

@testable import DriveSync

@Suite("OAuth flow")
struct OAuthFlowTests {
    @Test func configWithoutAClientIsNil() {
        #expect(GoogleOAuthConfig(clientId: "temp", redirectScheme: "temp") == nil)
        #expect(GoogleOAuthConfig(clientId: "", redirectScheme: "") == nil)
        #expect(GoogleOAuthConfig(clientId: "$(GOOGLE_CLIENT_ID)", redirectScheme: "x") == nil)
    }

    @Test func authorizationURLAsksForDriveFileOnlyWithPKCE() throws {
        let pkce = try PKCE(random: FakeRandom())
        let url = OAuthFlow.authorizationURL(config: testConfig, pkce: pkce)
        let request = URLRequest(url: url)

        #expect(url.host == "accounts.google.com")
        #expect(request.query("scope") == "https://www.googleapis.com/auth/drive.file")
        #expect(request.query("code_challenge") == pkce.challenge)
        #expect(request.query("code_challenge_method") == "S256")
        #expect(request.query("state") == pkce.state)
        #expect(request.query("redirect_uri") == "temp.scheme:/oauth2redirect")
        #expect(request.query("access_type") == "offline")
        #expect(!url.absoluteString.contains(pkce.verifier))
    }

    @Test func challengeIsTheSHA256OfTheVerifier() throws {
        let pkce = try PKCE(random: FakeRandom())
        #expect(pkce.verifier.count == 43)
        #expect(pkce.verifier.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
        #expect(pkce.challenge == Data(SHA256.hash(data: Data(pkce.verifier.utf8))).base64URLEncoded)
    }

    @Test func callbackNeedsTheMatchingState() throws {
        let ok = URL(string: "temp.scheme:/oauth2redirect?code=temp-code&state=temp-state")!
        #expect(try OAuthFlow.code(from: ok, config: testConfig, expectedState: "temp-state") == "temp-code")

        #expect(throws: DriveSignInError.failed) {
            try OAuthFlow.code(from: ok, config: testConfig, expectedState: "temp-other")
        }
        let foreign = URL(string: "other.scheme:/oauth2redirect?code=temp-code&state=temp-state")!
        #expect(throws: DriveSignInError.failed) {
            try OAuthFlow.code(from: foreign, config: testConfig, expectedState: "temp-state")
        }
        let denied = URL(string: "temp.scheme:/oauth2redirect?error=access_denied&state=temp-state")!
        #expect(throws: DriveSignInError.cancelled) {
            try OAuthFlow.code(from: denied, config: testConfig, expectedState: "temp-state")
        }
    }

    @Test func exchangeSendsTheVerifierAndNoSecret() throws {
        let pkce = try PKCE(random: FakeRandom())
        let form = OAuthFlow.exchangeRequest(code: "temp-code", pkce: pkce, config: testConfig).form
        #expect(form["grant_type"] == "authorization_code")
        #expect(form["code_verifier"] == pkce.verifier)
        #expect(form["client_id"] == testConfig.clientId)
        #expect(form["client_secret"] == nil)
    }
}

@Suite("Google auth")
struct GoogleAuthTests {
    let http = FakeHTTP()
    let clock = Clock()

    private func auth(
        config: GoogleOAuthConfig? = testConfig,
        store: MemoryTokenStore = MemoryTokenStore(),
        web: FakeWeb.Outcome = .approve
    ) -> GoogleAuth {
        let clock = clock
        return GoogleAuth(
            config: config,
            store: store,
            web: FakeWeb(outcome: web),
            transport: http.transport,
            random: FakeRandom(),
            now: { clock.now }
        )
    }

    private let tokenReply = #"{"access_token":"temp-access","expires_in":3600,"refresh_token":"temp-refresh"}"#

    @Test func signInStoresTheRefreshTokenAndKeepsAccessInMemory() async throws {
        let store = MemoryTokenStore()
        let auth = auth(store: store)
        http.reply(200, tokenReply)

        try await auth.signIn()

        #expect(store.load() == "temp-refresh")
        #expect(await auth.isSignedIn())
        #expect(try await auth.accessToken() == "temp-access")
        #expect(http.requests.count == 1)
    }

    @Test(arguments: [FakeWeb.Outcome.close, .deny])
    func closingOrDenyingIsACancel(outcome: FakeWeb.Outcome) async {
        let store = MemoryTokenStore()
        await #expect(throws: DriveSignInError.cancelled) {
            try await auth(store: store, web: outcome).signIn()
        }
        #expect(store.load() == nil)
        #expect(http.requests.isEmpty)
    }

    @Test func forgedRedirectIsRejectedBeforeAnyExchange() async {
        await #expect(throws: DriveSignInError.failed) {
            try await auth(web: .wrongState).signIn()
        }
        #expect(http.requests.isEmpty)
    }

    @Test func missingClientReportsNotConfigured() async {
        let auth = auth(config: nil, store: MemoryTokenStore("temp-refresh"))
        await #expect(throws: DriveSignInError.notConfigured) {
            try await auth.signIn()
        }
        #expect(await auth.isSignedIn() == false)
    }

    @Test func expiringAccessTokenIsRefreshedOnce() async throws {
        let auth = auth(store: MemoryTokenStore("temp-refresh"))
        http.reply(200, #"{"access_token":"temp-access-a","expires_in":3600}"#)
        #expect(try await auth.accessToken() == "temp-access-a")

        clock.advance(3600 - 30)
        http.reply(200, #"{"access_token":"temp-access-b","expires_in":3600}"#)
        async let first = auth.accessToken()
        async let second = auth.accessToken()
        let tokens = try await [first, second]

        #expect(tokens == ["temp-access-b", "temp-access-b"])
        #expect(http.requests.count == 2)
        #expect(http.requests[1].form["grant_type"] == "refresh_token")
        #expect(http.requests[1].form["refresh_token"] == "temp-refresh")
    }

    @Test func otherTokenErrorsKeepTheGrant() async {
        let store = MemoryTokenStore("temp-refresh")
        http.reply(400, #"{"error":"invalid_request"}"#)
        await #expect(throws: RemoteStoreError.server(status: 400)) {
            try await auth(store: store).accessToken()
        }
        #expect(store.load() == "temp-refresh")
    }

    /// The code is single-use: a retry after a dropped connection would only fail.
    @Test func codeExchangeIsNotRetried() async {
        http.fail(.networkConnectionLost)
        http.reply(200, tokenReply)
        await #expect(throws: DriveSignInError.offline) {
            try await auth().signIn()
        }
        #expect(http.requests.count == 1)
    }

    @Test func revokedGrantSignsOut() async {
        let store = MemoryTokenStore("temp-refresh")
        let auth = auth(store: store)
        http.reply(400, #"{"error":"invalid_grant"}"#)

        await #expect(throws: RemoteStoreError.signedOut) {
            try await auth.accessToken()
        }
        #expect(store.load() == nil)
    }

    @Test func signOutForgetsFirstThenRevokes() async throws {
        let store = MemoryTokenStore("temp-refresh")
        let auth = auth(store: store)
        http.reply(200)

        await auth.signOut()

        #expect(store.load() == nil)
        #expect(http.requests.first?.url?.host == "oauth2.googleapis.com")
        #expect(http.requests.first?.form["token"] == "temp-refresh")
        await #expect(throws: RemoteStoreError.signedOut) {
            try await auth.accessToken()
        }
    }
}

@Suite("Drive client")
struct DriveClientTests {
    let http = FakeHTTP()
    let tokens = FakeTokens()

    var client: DriveClient { DriveClient(tokens: tokens, transport: http.transport) }

    @Test func headWithoutAFileIsNil() async throws {
        http.reply(200, #"{"files":[]}"#)
        #expect(try await client.head() == nil)

        let request = try #require(http.requests.first)
        #expect(
            request.query("q")
                == "appProperties has { key='tnRole' and value='ledger' } and 'me' in owners and trashed = false"
        )
        #expect(request.query("orderBy") == "createdTime")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer temp-access-1")
        #expect(!(request.url?.absoluteString.contains("temp-access") ?? true))
    }

    @Test func firstUploadCreatesFolderAndFileThenPins() async throws {
        let client = client
        http.reply(200, #"{"files":[]}"#)  // ledger lookup
        http.reply(200, #"{"files":[]}"#)  // folder lookup
        http.reply(200, #"{"id":"temp-folder"}"#)
        http.reply(200, #"{"id":"temp-file","headRevisionId":"temp-rev-1"}"#)
        http.reply(200, #"{"id":"temp-rev-1"}"#)  // keepForever

        let revision = try await client.upload(Data("temp-ledger".utf8), pin: true)

        #expect(revision == RemoteRevision("temp-rev-1"))
        let requests = http.requests
        #expect(requests.count == 5)
        #expect(requests[2].httpMethod == "POST")
        #expect(requests[2].bodyText.contains(#""mimeType":"application\/vnd.google-apps.folder""#))
        let create = requests[3]
        #expect(create.query("uploadType") == "multipart")
        #expect(create.bodyText.contains(#""parents":["temp-folder"]"#))
        #expect(create.bodyText.contains(#""tnRole":"ledger""#))
        #expect(create.bodyText.contains("temp-ledger"))
        #expect(requests[4].httpMethod == "PATCH")
        #expect(requests[4].url?.path().hasSuffix("files/temp-file/revisions/temp-rev-1") == true)
        #expect(requests[4].bodyText == #"{"keepForever":true}"#)
    }

    @Test func laterUploadReplacesContentWithoutPin() async throws {
        let client = client
        http.reply(200, #"{"files":[{"id":"temp-file","headRevisionId":"temp-rev-1"}]}"#)
        _ = try await client.head()
        http.reply(200, #"{"id":"temp-file","headRevisionId":"temp-rev-2"}"#)

        #expect(try await client.upload(Data("temp".utf8), pin: false) == RemoteRevision("temp-rev-2"))

        let upload = try #require(http.requests.last)
        #expect(upload.httpMethod == "PATCH")
        #expect(upload.query("uploadType") == "media")
        #expect(upload.url?.path().hasSuffix("files/temp-file") == true)
        #expect(http.requests.count == 2)
    }

    @Test func downloadReadsTheGivenRevision() async throws {
        let client = client
        http.reply(200, #"{"files":[{"id":"temp-file","headRevisionId":"temp-rev-2"}]}"#)
        let head = try #require(try await client.head())
        http.reply(200, "temp-bytes")

        #expect(try await client.download(head) == Data("temp-bytes".utf8))
        let request = try #require(http.requests.last)
        #expect(request.url?.path().hasSuffix("files/temp-file/revisions/temp-rev-2") == true)
        #expect(request.query("alt") == "media")
    }

    @Test func revisionsAfterFollowPagesAndSlice() async throws {
        let client = client
        http.reply(200, #"{"files":[{"id":"temp-file","headRevisionId":"r4"}]}"#)
        _ = try await client.head()
        http.reply(200, #"{"revisions":[{"id":"r1"},{"id":"r2"}],"nextPageToken":"temp-page"}"#)
        http.reply(200, #"{"revisions":[{"id":"r3"},{"id":"r4"}]}"#)

        #expect(
            try await client.revisions(after: RemoteRevision("r2")) == [RemoteRevision("r3"), RemoteRevision("r4")]
        )
        #expect(http.requests.last?.query("pageToken") == "temp-page")
    }

    /// Debug builds look for and create their own markers, so they never touch the released
    /// app's file, whichever way Google scopes `drive.file` across clients of one project.
    @Test func devNamespaceUsesItsOwnMarkersAndFolder() async throws {
        let dev = DriveClient(tokens: tokens, transport: http.transport, namespace: "dev")
        http.reply(200, #"{"files":[]}"#)
        http.reply(200, #"{"files":[]}"#)
        http.reply(200, #"{"id":"temp-folder"}"#)
        http.reply(200, #"{"id":"temp-file","headRevisionId":"temp-rev-1"}"#)

        _ = try await dev.upload(Data("temp".utf8), pin: false)

        let requests = http.requests
        #expect(requests[0].query("q")?.contains("value='ledger-dev'") == true)
        #expect(requests[1].query("q")?.contains("value='folder-dev'") == true)
        #expect(requests[2].bodyText.contains(#""name":"Tenure (dev)""#))
        #expect(requests[3].bodyText.contains(#""tnRole":"ledger-dev""#))
        #expect(await client.marker("ledger") == "ledger")
    }

    /// A create that may have taken effect is not repeated; a duplicate file would follow.
    @Test func createIsNotRetriedAfterAServerError() async throws {
        http.reply(200, #"{"files":[]}"#)
        http.reply(200, #"{"files":[{"id":"temp-folder"}]}"#)
        http.reply(503)
        http.reply(200, #"{"id":"temp-file","headRevisionId":"temp-rev-1"}"#)

        await #expect(throws: RemoteStoreError.server(status: 503)) {
            try await client.upload(Data("temp".utf8), pin: false)
        }
        #expect(http.requests.count == 3)
    }

    @Test func expiredTokenGetsOneRetryWithAFreshOne() async throws {
        http.reply(401)
        http.reply(200, #"{"files":[]}"#)

        #expect(try await client.head() == nil)
        #expect(await tokens.invalidations == 1)
        #expect(http.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer temp-access-2")
    }

    @Test func secondUnauthorizedIsSignedOut() async {
        http.reply(401)
        http.reply(401)
        await #expect(throws: RemoteStoreError.signedOut) {
            try await client.head()
        }
    }

    @Test func rateLimitsAndServerErrorsAreRetriedThenReported() async throws {
        http.reply(429)
        http.reply(403, #"{"error":{"errors":[{"reason":"userRateLimitExceeded"}]}}"#)
        http.reply(200, #"{"files":[]}"#)
        #expect(try await client.head() == nil)
        #expect(http.requests.count == 3)

        for _ in 0..<HTTPTransport.maxAttempts { http.reply(503) }
        await #expect(throws: RemoteStoreError.server(status: 503)) {
            try await client.head()
        }
    }

    @Test func noConnectionIsOffline() async {
        for _ in 0..<HTTPTransport.maxAttempts { http.fail(.notConnectedToInternet) }
        await #expect(throws: RemoteStoreError.offline) {
            try await client.head()
        }
    }

    @Test func signedOutAccountMakesNoRequest() async {
        await tokens.signOut()
        await #expect(throws: RemoteStoreError.signedOut) {
            try await client.head()
        }
        #expect(http.requests.isEmpty)
    }
}
