import Domain
import Foundation

/// Sends one request, retrying transient failures (rate limits, 5xx, a dropped connection)
/// with exponential backoff, and maps what is left to `RemoteStoreError`. Tests inject
/// `perform` instead of the network.
struct HTTPTransport: Sendable {
    static let maxAttempts = 3

    private let perform: @Sendable (URLRequest) async throws -> (Data, URLResponse)
    private let sleep: @Sendable (Duration) async -> Void

    init(
        perform: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse),
        sleep: @escaping @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    ) {
        self.perform = perform
        self.sleep = sleep
    }

    init(session: URLSession) {
        self.init(perform: { try await session.data(for: $0) })
    }

    /// Returns any final HTTP status; the caller decides what a 4xx means. A request that is
    /// not `idempotent` (it creates something, or spends a one-time code) is retried only on a
    /// rate limit, which Google answers before acting; after a dropped connection or a 5xx it
    /// may already have taken effect, and a second try would duplicate it or fail.
    func send(_ request: URLRequest, idempotent: Bool = true) async throws -> (Data, HTTPURLResponse) {
        var attempt = 1
        while true {
            do {
                let (data, response) = try await perform(request)
                guard let http = response as? HTTPURLResponse else { throw RemoteStoreError.server(status: 0) }
                let retryable =
                    idempotent
                    ? Self.isTransient(http.statusCode, body: data)
                    : http.statusCode == 429 || (http.statusCode == 403 && Self.isRateLimit(data))
                if retryable, attempt < Self.maxAttempts {
                    await sleep(Self.backoff(attempt))
                    attempt += 1
                    continue
                }
                return (data, http)
            } catch let error as URLError {
                guard error.code != .cancelled else { throw error }
                if idempotent, attempt < Self.maxAttempts {
                    await sleep(Self.backoff(attempt))
                    attempt += 1
                    continue
                }
                throw Self.map(error)
            }
        }
    }

    /// 2xx passes; anything else becomes the matching `RemoteStoreError`.
    static func check(_ response: HTTPURLResponse, body: Data) throws {
        switch response.statusCode {
        case 200..<300: return
        case 401: throw RemoteStoreError.signedOut
        case 404: throw RemoteStoreError.notFound
        case 429: throw RemoteStoreError.rateLimited
        case 403 where isRateLimit(body): throw RemoteStoreError.rateLimited
        default: throw RemoteStoreError.server(status: response.statusCode)
        }
    }

    static func isTransient(_ status: Int, body: Data) -> Bool {
        status == 429 || (500...599).contains(status) || (status == 403 && isRateLimit(body))
    }

    /// Drive reports quota errors as 403 with a reason in the body.
    static func isRateLimit(_ body: Data) -> Bool {
        let text = String(decoding: body, as: UTF8.self)
        return text.contains("rateLimitExceeded") || text.contains("userRateLimitExceeded")
    }

    /// 0.5 s, 1 s, 2 s, ... plus up to 250 ms of jitter, so two Macs do not retry in step.
    static func backoff(_ attempt: Int) -> Duration {
        .milliseconds(500 * (1 << (attempt - 1)) + Int.random(in: 0...250))
    }

    static func map(_ error: URLError) -> RemoteStoreError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost,
            .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff:
            .offline
        default:
            .server(status: 0)
        }
    }
}
