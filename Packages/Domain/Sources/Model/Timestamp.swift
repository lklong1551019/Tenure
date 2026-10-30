import Foundation

/// Milliseconds since 1970. An integer, so it round-trips exactly through the data file; a
/// `Date` would drift through floating point.
public struct Timestamp: Sendable, Hashable, Comparable, Codable {
    public static let millisPerDay: Int64 = 86_400_000

    public let millis: Int64

    public init(millis: Int64) {
        self.millis = millis
    }

    public init(_ date: Date) {
        self.millis = Int64((date.timeIntervalSince1970 * 1000).rounded(.down))
    }

    public var date: Date {
        Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
    }

    /// Saturates instead of trapping: a stored value can come from an edited file.
    public func adding(days: Int) -> Timestamp {
        let (delta, overflow) = Int64(days).multipliedReportingOverflow(by: Timestamp.millisPerDay)
        return overflow ? Timestamp(millis: days < 0 ? .min : .max) : adding(millis: delta)
    }

    public func adding(millis delta: Int64) -> Timestamp {
        let (sum, overflow) = millis.addingReportingOverflow(delta)
        return Timestamp(millis: overflow ? (delta < 0 ? .min : .max) : sum)
    }

    public static func < (lhs: Timestamp, rhs: Timestamp) -> Bool {
        lhs.millis < rhs.millis
    }

    public init(from decoder: any Decoder) throws {
        millis = try decoder.singleValueContainer().decode(Int64.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(millis)
    }
}
