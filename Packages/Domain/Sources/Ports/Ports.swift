import Foundation

/// The data file on this Mac. Throws `LedgerError`.
public protocol LedgerRepository: Sendable {
    /// Nil when nothing was saved yet.
    func load() throws -> LedgerSnapshot?
    /// Atomic: the previous file stays intact if the write fails.
    func save(_ snapshot: LedgerSnapshot) throws
}

/// The file format, shared by the local file and the remote copy. Decoding refuses a newer
/// format version with `LedgerError.unsupportedFormatVersion`.
public protocol LedgerCodecPort: Sendable {
    func encode(_ snapshot: LedgerSnapshot) throws -> Data
    func decode(_ data: Data) throws -> LedgerSnapshot
}

public protocol ClockPort: Sendable {
    func now() -> Timestamp
}

public struct SystemClock: ClockPort {
    public init() {}

    public func now() -> Timestamp {
        Timestamp(Date())
    }
}

public protocol RandomPort: Sendable {
    func bytes(count: Int) throws -> Data
}

/// The system CSPRNG (`SystemRandomNumberGenerator` reads from the kernel).
public struct SystemRandom: RandomPort {
    public init() {}

    public func bytes(count: Int) throws -> Data {
        var generator = SystemRandomNumberGenerator()
        return Data((0..<count).map { _ in UInt8.random(in: .min ... .max, using: &generator) })
    }
}
