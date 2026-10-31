import Foundation

/// One published build and its notes, as `scripts/release.sh` writes them to
/// `App/Sources/Changelog.json`. A version can ship more than once: 26.11.01 is build 26110101,
/// and a later build of it is 26110103.
public struct Release: Sendable, Hashable, Codable, Identifiable {
    public let version: String
    /// The build code, YYMMNNBB.
    public let code: Int
    /// "2026-11-02", as written by the release script.
    public let date: String
    public let new: [String]
    public let fixed: [String]
    public let improved: [String]

    public var id: Int { code }

    /// "26.11.01 - 26110103": the version, then the build code that tells builds apart.
    public var title: String {
        "\(version) - \(code)"
    }

    public init(
        version: String,
        code: Int? = nil,
        date: String = "",
        new: [String] = [],
        fixed: [String] = [],
        improved: [String] = []
    ) {
        self.version = version
        self.code = code ?? UpdateCheck.firstBuild(of: version)
        self.date = date
        self.new = new
        self.fixed = fixed
        self.improved = improved
    }

    private enum CodingKeys: String, CodingKey {
        case version, code, date, new, fixed, improved
    }

    /// Only `version` is required; a field a later script adds or drops never fails the feed.
    /// A missing or unreadable code reads as the version's first build.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: .version)
        code =
            container.lenient(String.self, forKey: .code).flatMap { Int($0) }
            ?? container.lenient(Int.self, forKey: .code)
            ?? UpdateCheck.firstBuild(of: version)
        date = container.lenient(String.self, forKey: .date) ?? ""
        new = container.lenient([String].self, forKey: .new) ?? []
        fixed = container.lenient([String].self, forKey: .fixed) ?? []
        improved = container.lenient([String].self, forKey: .improved) ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(String(code), forKey: .code)
        try container.encode(date, forKey: .date)
        try container.encode(new, forKey: .new)
        try container.encode(fixed, forKey: .fixed)
        try container.encode(improved, forKey: .improved)
    }
}

/// Where the app learns about new builds: the published changelog.
public protocol ReleaseFeedPort: Sendable {
    func releases() async throws -> [Release]
}

/// Builds compare by code, not by version: 26.11.01 - 26110103 is newer than
/// 26.11.01 (26110101) though the version reads the same.
public enum UpdateCheck {
    /// A larger changelog is refused rather than read: the real one is a few kilobytes.
    public static let maximumFeedBytes = 256 * 1024
    /// At most this many newer releases are shown.
    public static let maximumShown = 20

    /// The releases in a changelog file (`{"releases": [...]}`), newest build first. Entries
    /// whose version is not `YY.MM.NN` or whose code is not eight digits are dropped: the feed
    /// comes from the network.
    public static func decode(_ data: Data) throws -> [Release] {
        guard data.count <= maximumFeedBytes else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "feed too large"))
        }
        struct Feed: Decodable { let releases: [Release] }
        return try JSONDecoder().decode(Feed.self, from: data).releases
            .filter { $0.version.wholeMatch(of: /[0-9]{2}\.[0-9]{2}\.[0-9]{2}/) != nil }
            .filter { (10_000_000...99_999_999).contains($0.code) }
            .sorted { $0.code > $1.code }
    }

    /// Releases with a higher code than `currentCode` (this build's CFBundleVersion), newest
    /// first, at most `maximumShown`.
    public static func newer(than currentCode: Int, in releases: [Release]) -> [Release] {
        Array(releases.filter { $0.code > currentCode }.sorted { $0.code > $1.code }.prefix(maximumShown))
    }

    /// "26110101" as a number; anything else reads as 0, so every release counts as newer.
    public static func code(_ text: String) -> Int {
        Int(text.trimmingCharacters(in: .whitespaces)) ?? 0
    }

    /// The code of a version's first build: 26.11.01 is 26110101.
    public static func firstBuild(of version: String) -> Int {
        (Int(version.filter(\.isNumber)) ?? 0) * 100 + 1
    }
}
