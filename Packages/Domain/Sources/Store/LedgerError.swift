import Foundation

public enum LedgerError: Error, Sendable, Equatable {
    /// The file was written by a newer build. Refused rather than guessed at.
    case unsupportedFormatVersion(Int)
    /// Not a Tenure file, or not valid JSON.
    case corruptFile
    /// The local write failed; the previous file and the in-memory state are unchanged.
    case saveFailed
    case notFound
}
