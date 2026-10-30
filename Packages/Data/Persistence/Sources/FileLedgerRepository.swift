import Domain
import Foundation

/// Stores `tenure.json` on local disk. Owner-only permissions; replaced atomically, so a crash
/// mid-write leaves the previous file intact.
public struct FileLedgerRepository: LedgerRepository {
    public let fileURL: URL
    private let codec: LedgerFileCodec

    public init(fileURL: URL, codec: LedgerFileCodec = LedgerFileCodec()) {
        self.fileURL = fileURL
        self.codec = codec
    }

    /// `~/Library/Application Support/Tenure/tenure.json`, inside the sandbox container when
    /// the app is sandboxed.
    public static func defaultFileURL() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return support.appending(path: "Tenure", directoryHint: .isDirectory)
            .appending(path: "tenure.json", directoryHint: .notDirectory)
    }

    public func load() throws -> LedgerSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw LedgerError.corruptFile
        }
        return try codec.decode(data)
    }

    public func save(_ snapshot: LedgerSnapshot) throws {
        do {
            try AtomicFile.write(try codec.encode(snapshot), to: fileURL)
        } catch {
            throw LedgerError.saveFailed
        }
    }
}

enum AtomicFile {
    static let filePermissions: Int = 0o600
    static let directoryPermissions: Int = 0o700

    /// Write to a sibling temp file, fsync, then rename(2) over the target.
    static func write(_ data: Data, to url: URL) throws {
        let fileManager = FileManager.default
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: directoryPermissions]
        )
        let temp = directory.appending(path: ".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        guard fileManager.createFile(atPath: temp.path, contents: nil, attributes: [.posixPermissions: filePermissions])
        else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: temp.path])
        }
        do {
            let handle = try FileHandle(forWritingTo: temp)
            defer { try? handle.close() }
            try handle.write(contentsOf: data)
            try handle.synchronize()
            guard rename(temp.path, url.path) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
        } catch {
            try? fileManager.removeItem(at: temp)
            throw error
        }
    }
}
