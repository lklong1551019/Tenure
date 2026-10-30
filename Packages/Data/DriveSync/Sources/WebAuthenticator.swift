import AppKit
import AuthenticationServices
import Domain
import Foundation

/// Shows a sign-in page and returns the redirect URL.
protocol WebAuthenticating: Sendable {
    func authenticate(url: URL, callbackScheme: String) async throws -> URL
}

/// The system sign-in sheet. It runs in a browser context the app cannot read, so the Google
/// password is never visible to the app; sharing Safari's cookies lets an already signed-in
/// account skip typing it.
struct SystemWebAuthenticator: WebAuthenticating {
    func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        try await MainActor.run { SheetPresenter() }.run(url: url, callbackScheme: callbackScheme)
    }
}

@MainActor
private final class SheetPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func run(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            // AuthenticationServices calls this on a background queue. Marked `@Sendable` so it
            // is not main-actor isolated like the code around it; otherwise Swift traps there.
            let completion: @Sendable (URL?, (any Error)?) -> Void = { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                    continuation.resume(throwing: DriveSignInError.cancelled)
                } else {
                    continuation.resume(throwing: DriveSignInError.failed)
                }
            }
            let session = ASWebAuthenticationSession(
                url: url,
                callback: .customScheme(callbackScheme),
                completionHandler: completion
            )
            session.presentationContextProvider = self
            self.session = session
            if !session.start() {
                continuation.resume(throwing: DriveSignInError.failed)
            }
        }
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated { NSApplication.shared.keyWindow ?? ASPresentationAnchor() }
    }
}
