import Domain
import Foundation

/// `tenure.json`: plain, pretty-printed JSON with sorted keys, so the file reads well, diffs
/// cleanly, and survives a hand edit. The same bytes go to the local file and to Drive.
///
///     { "format": "tenure", "version": 1, "boards": [...], "entries": [...] }
public struct LedgerFileCodec: LedgerCodecPort {
    public static let format = "tenure"
    public static let currentVersion = 1

    public init() {}

    public func encode(_ snapshot: LedgerSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let file = File(
            format: Self.format,
            version: Self.currentVersion,
            boards: snapshot.boards.sorted { $0.id.uuidString < $1.id.uuidString },
            entries: snapshot.entries.sorted { $0.id.uuidString < $1.id.uuidString }
        )
        return try encoder.encode(file)
    }

    /// Throws `LedgerError.unsupportedFormatVersion` for a newer file and `.corruptFile` for
    /// anything that is not a Tenure file or repeats an id.
    public func decode(_ data: Data) throws -> LedgerSnapshot {
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.format == Self.format else {
            throw LedgerError.corruptFile
        }
        guard header.version <= Self.currentVersion else {
            throw LedgerError.unsupportedFormatVersion(header.version)
        }
        guard let file = try? decoder.decode(File.self, from: data) else { throw LedgerError.corruptFile }
        guard Set(file.boards.map(\.id)).count == file.boards.count,
            Set(file.entries.map(\.id)).count == file.entries.count
        else {
            throw LedgerError.corruptFile
        }
        return LedgerSnapshot(boards: file.boards, entries: file.entries)
    }

    private struct Header: Decodable {
        let format: String
        let version: Int
    }

    private struct File: Codable {
        let format: String
        let version: Int
        let boards: [Board]
        let entries: [Entry]
    }
}
