import Foundation

/// One published version and its notes, as `scripts/release.sh` writes them to
/// `App/Sources/Changelog.json`.
public struct Release: Sendable, Hashable, Codable, Identifiable {
    public let version: String
    /// "2026-11-02", as written by the release script.
    public let date: String
    public let new: [String]
    public let fixed: [String]
    public let improved: [String]

    public var id: String { version }

    public init(
        version: String,
        date: String = "",
        new: [String] = [],
        fixed: [String] = [],
        improved: [String] = []
    ) {
        self.version = version
        self.date = date
        self.new = new
        self.fixed = fixed
        self.improved = improved
    }

    private enum CodingKeys: String, CodingKey {
        case version, date, new, fixed, improved
    }

    /// Only `version` is required; a field a later script adds or drops never fails the feed.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: .version)
        date = container.lenient(String.self, forKey: .date) ?? ""
        new = container.lenient([String].self, forKey: .new) ?? []
        fixed = container.lenient([String].self, forKey: .fixed) ?? []
        improved = container.lenient([String].self, forKey: .improved) ?? []
    }
}

/// Where the app learns about new versions: the published changelog.
public protocol ReleaseFeedPort: Sendable {
    func releases() async throws -> [Release]
}

public enum UpdateCheck {
    /// A larger changelog is refused rather than read: the real one is a few kilobytes.
    public static let maximumFeedBytes = 256 * 1024
    /// At most this many newer releases are shown.
    public static let maximumShown = 20

    /// The releases in a changelog file (`{"releases": [...]}`), newest first. Entries whose
    /// version is not dotted numbers (`26.11.01`) are dropped: the feed comes from the network.
    public static func decode(_ data: Data) throws -> [Release] {
        guard data.count <= maximumFeedBytes else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "feed too large"))
        }
        struct Feed: Decodable { let releases: [Release] }
        return try JSONDecoder().decode(Feed.self, from: data).releases
            .filter { $0.version.wholeMatch(of: /[0-9]{1,4}(\.[0-9]{1,4}){0,3}/) != nil }
            .sorted { isNewer($0.version, than: $1.version) }
    }

    /// Releases newer than `current`, newest first, at most `maximumShown`. Versions compare
    /// part by part as numbers, so 26.11.01 is newer than 26.10.12.
    public static func newer(than current: String, in releases: [Release]) -> [Release] {
        Array(
            releases.filter { isNewer($0.version, than: current) }
                .sorted { isNewer($0.version, than: $1.version) }
                .prefix(maximumShown)
        )
    }

    public static func isNewer(_ version: String, than other: String) -> Bool {
        let lhs = parts(version)
        let rhs = parts(other)
        for index in 0..<max(lhs.count, rhs.count) {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right { return left > right }
        }
        return false
    }

    private static func parts(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0) ?? 0 }
    }
}
