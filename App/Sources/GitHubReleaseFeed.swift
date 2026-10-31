import Domain
import Foundation

/// The published changelog on GitHub. It changes only in release commits, so the copy on
/// `main` lists exactly the released versions. Off the main actor: the download and decode
/// never hold up the UI. No cookies or disk cache, and a size cap, since it is network input.
nonisolated struct GitHubReleaseFeed: ReleaseFeedPort {
    static let changelog = URL(
        string: "https://raw.githubusercontent.com/lklong1551019/Tenure/main/App/Sources/Changelog.json"
    )!
    static let releasePage = URL(string: "https://lklong1551019.github.io/Tenure/releases.html")!

    private static let session = URLSession(configuration: .ephemeral)

    @concurrent
    func releases() async throws -> [Release] {
        var request = URLRequest(url: Self.changelog, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await Self.session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
            http.expectedContentLength <= Int64(UpdateCheck.maximumFeedBytes)
        else {
            throw URLError(.badServerResponse)
        }
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
            // Stops reading a body larger than any real changelog; decode refuses it.
            if data.count > UpdateCheck.maximumFeedBytes { break }
        }
        return try UpdateCheck.decode(data)
    }
}
