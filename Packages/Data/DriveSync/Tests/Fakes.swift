import CryptoKit
import Domain
import Foundation

@testable import DriveSync

/// Scripted HTTP: answers requests in order from a queue and records what was sent.
final class FakeHTTP: @unchecked Sendable {
    // Invariant for @unchecked Sendable: every access goes through `lock`.
    typealias Reply = (status: Int, body: Data)

    private let lock = NSLock()
    private var replies: [Result<Reply, URLError>] = []
    private var sent: [URLRequest] = []

    var requests: [URLRequest] { lock.withLock { sent } }

    func reply(_ status: Int, _ json: String = "{}") {
        lock.withLock { replies.append(.success((status, Data(json.utf8)))) }
    }

    func fail(_ code: URLError.Code) {
        lock.withLock { replies.append(.failure(URLError(code))) }
    }

    var transport: HTTPTransport {
        HTTPTransport(perform: { try self.respond(to: $0) }, sleep: { _ in })
    }

    private func respond(to request: URLRequest) throws -> (Data, URLResponse) {
        let next = lock.withLock { () -> Result<Reply, URLError>? in
            sent.append(request)
            return replies.isEmpty ? nil : replies.removeFirst()
        }
        guard let next else { throw URLError(.badServerResponse) }
        let reply = try next.get()
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: reply.status,
            httpVersion: nil,
            headerFields: nil
        )!
        return (reply.body, response)
    }
}

final class MemoryTokenStore: RefreshTokenStore, @unchecked Sendable {
    // Invariant for @unchecked Sendable: every access goes through `lock`.
    private let lock = NSLock()
    private var token: String?

    init(_ token: String? = nil) {
        self.token = token
    }

    func load() -> String? { lock.withLock { token } }
    func save(_ token: String) throws { lock.withLock { self.token = token } }
    func delete() { lock.withLock { token = nil } }
}

/// Plays Google's sign-in page: echoes the request's `state` back, or fails as scripted.
struct FakeWeb: WebAuthenticating {
    enum Outcome: Sendable {
        case approve
        case wrongState
        case deny
        case close
    }

    let outcome: Outcome

    func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        let state =
            URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
            .first { $0.name == "state" }?.value ?? ""
        switch outcome {
        case .approve: return URL(string: "\(callbackScheme):/oauth2redirect?code=temp&state=\(state)")!
        case .wrongState: return URL(string: "\(callbackScheme):/oauth2redirect?code=temp&state=temp")!
        case .deny: return URL(string: "\(callbackScheme):/oauth2redirect?error=access_denied&state=\(state)")!
        case .close: throw DriveSignInError.cancelled
        }
    }
}

struct FakeRandom: RandomPort {
    func bytes(count: Int) throws -> Data {
        Data((0..<count).map { _ in UInt8.random(in: .min ... .max) })
    }
}

final class Clock: @unchecked Sendable {
    // Invariant for @unchecked Sendable: every access goes through `lock`.
    private let lock = NSLock()
    private var value = Date(timeIntervalSince1970: 1_790_000_000)

    var now: Date { lock.withLock { value } }
    func advance(_ seconds: TimeInterval) { lock.withLock { value.addTimeInterval(seconds) } }
}

/// Hands out numbered tokens and counts invalidations.
actor FakeTokens: AccessTokenProviding {
    private var issued = 0
    private(set) var invalidations = 0
    var signedOut = false

    func accessToken() async throws -> String {
        if signedOut { throw RemoteStoreError.signedOut }
        issued += 1
        return "temp-access-\(issued)"
    }

    func invalidateAccessToken() async {
        invalidations += 1
    }

    func signOut() {
        signedOut = true
    }
}

let testConfig = GoogleOAuthConfig(clientId: "temp-client", redirectScheme: "temp.scheme")!

extension URLRequest {
    var bodyText: String { String(decoding: httpBody ?? Data(), as: UTF8.self) }

    func query(_ name: String) -> String? {
        URLComponents(url: url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
    }

    var form: [String: String] {
        Dictionary(
            uniqueKeysWithValues: bodyText.split(separator: "&").map { pair in
                let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
                return (parts[0], parts.count > 1 ? (parts[1].removingPercentEncoding ?? parts[1]) : "")
            }
        )
    }
}
