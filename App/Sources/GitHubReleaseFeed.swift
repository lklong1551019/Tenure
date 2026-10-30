import Domain
import Foundation

/// The published changelog on GitHub. It changes only in release commits, so the copy on
/// `main` lists exactly the released versions.
struct GitHubReleaseFeed: ReleaseFeedPort {
    static let changelog = URL(
        string: "https://raw.githubusercontent.com/lklong1551019/Tenure/main/App/Sources/Changelog.json"
    )!
    static let releasePage = URL(string: "https://lklong1551019.github.io/Tenure/releases.html")!

    func releases() async throws -> [Release] {
        var request = URLRequest(url: Self.changelog, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try UpdateCheck.decode(data)
    }
}
