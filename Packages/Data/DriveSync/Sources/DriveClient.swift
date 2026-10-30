import Domain
import Foundation

/// The data file in Google Drive (REST v3). One file, `tenure.json`, in a "Tenure" folder;
/// both are found by an `appProperties` marker, never by name, so a renamed or moved file is
/// still found and a same-named file the user made is ignored. The bytes come from
/// `LedgerCodecPort` unchanged.
public actor DriveClient: RemoteStorePort {
    static let api = URL(string: "https://www.googleapis.com/drive/v3/")!
    static let uploadAPI = URL(string: "https://www.googleapis.com/upload/drive/v3/")!
    static let roleKey = "tnRole"
    static let fileName = "tenure.json"

    private let tokens: any AccessTokenProviding
    private let transport: HTTPTransport
    /// Empty for the released app; "dev" for Debug builds, whose file and folder carry their
    /// own markers so they never read or replace the real app's copy.
    private let namespace: String
    /// The data file found by the last `head()`, so the calls of one round share it.
    private var fileId: String?

    public init(auth: GoogleAuth, namespace: String = "", session: URLSession = .shared) {
        self.init(tokens: auth, transport: HTTPTransport(session: session), namespace: namespace)
    }

    init(tokens: any AccessTokenProviding, transport: HTTPTransport, namespace: String = "") {
        self.tokens = tokens
        self.transport = transport
        self.namespace = namespace.trimmingCharacters(in: .whitespaces)
    }

    var folderName: String {
        namespace.isEmpty ? "Tenure" : "Tenure (\(namespace))"
    }

    func marker(_ role: String) -> String {
        namespace.isEmpty ? role : "\(role)-\(namespace)"
    }

    public func head() async throws -> RemoteRevision? {
        let file = try await find(role: "ledger")
        fileId = file?.id
        return file.map { RemoteRevision($0.headRevisionId ?? "") }
    }

    public func download(_ revision: RemoteRevision) async throws -> Data {
        let id = try await existingFileId()
        let url = Self.api.appending(path: "files/\(id)/revisions/\(revision.id)")
            .appending(queryItems: [URLQueryItem(name: "alt", value: "media")])
        return try await authorized(URLRequest(url: url))
    }

    public func upload(_ data: Data, pin: Bool) async throws -> RemoteRevision {
        let file: DriveFile
        if let id = try await currentFileId() {
            file = try await replaceContent(of: id, with: data)
        } else {
            file = try await createFile(with: data)
        }
        fileId = file.id
        guard let revision = file.headRevisionId else { throw RemoteStoreError.server(status: 0) }
        if pin {
            // A missed pin only costs one long-term backup; the upload itself succeeded.
            try? await keepForever(fileId: file.id, revision: revision)
        }
        return RemoteRevision(revision)
    }

    public func revisions(after revision: RemoteRevision) async throws -> [RemoteRevision] {
        let id = try await existingFileId()
        var all: [String] = []
        var pageToken: String?
        repeat {
            var items = [
                URLQueryItem(name: "fields", value: "nextPageToken,revisions(id)"),
                URLQueryItem(name: "pageSize", value: "200"),
            ]
            if let pageToken { items.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            let url = Self.api.appending(path: "files/\(id)/revisions").appending(queryItems: items)
            let page = try decode(RevisionPage.self, from: try await authorized(URLRequest(url: url)))
            all += page.revisions.map(\.id)
            pageToken = page.nextPageToken
        } while pageToken != nil
        // Drive lists oldest first. A base Drive already pruned cannot be placed; nothing is
        // reported, and the next round's head check catches up.
        guard let index = all.firstIndex(of: revision.id) else { return [] }
        return all[(index + 1)...].map(RemoteRevision.init)
    }

    // MARK: Files

    private func currentFileId() async throws -> String? {
        if let fileId { return fileId }
        fileId = try await find(role: "ledger")?.id
        return fileId
    }

    private func existingFileId() async throws -> String {
        guard let id = try await currentFileId() else { throw RemoteStoreError.notFound }
        return id
    }

    /// The oldest match wins, so two Macs that both created a file on their first round agree
    /// on one; the other is never read again.
    private func find(role: String) async throws -> DriveFile? {
        // Owned by the signed-in account: a file shared into it never stands in for the ledger.
        let query =
            "appProperties has { key='\(Self.roleKey)' and value='\(marker(role))' } and 'me' in owners and trashed = false"
        let url = Self.api.appending(path: "files").appending(queryItems: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "spaces", value: "drive"),
            URLQueryItem(name: "orderBy", value: "createdTime"),
            URLQueryItem(name: "pageSize", value: "10"),
            URLQueryItem(name: "fields", value: "files(id,headRevisionId)"),
        ])
        return try decode(FileList.self, from: try await authorized(URLRequest(url: url))).files.first
    }

    private func createFile(with data: Data) async throws -> DriveFile {
        let folder: DriveFile
        if let existing = try await find(role: "folder") {
            folder = existing
        } else {
            folder = try await createFolder()
        }
        let metadata = FileMetadata(
            name: Self.fileName,
            mimeType: "application/json",
            parents: [folder.id],
            appProperties: [Self.roleKey: marker("ledger")]
        )
        let boundary = "tn-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n")
        body.append(try JSONEncoder().encode(metadata))
        body.append("\r\n--\(boundary)\r\nContent-Type: application/json\r\n\r\n")
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n")
        var request = URLRequest(
            url: Self.uploadAPI.appending(path: "files").appending(queryItems: [
                URLQueryItem(name: "uploadType", value: "multipart"),
                URLQueryItem(name: "fields", value: "id,headRevisionId"),
            ])
        )
        request.httpMethod = "POST"
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return try decode(DriveFile.self, from: try await authorized(request, idempotent: false))
    }

    private func createFolder() async throws -> DriveFile {
        let metadata = FileMetadata(
            name: folderName,
            mimeType: "application/vnd.google-apps.folder",
            parents: nil,
            appProperties: [Self.roleKey: marker("folder")]
        )
        var request = URLRequest(
            url: Self.api.appending(path: "files").appending(queryItems: [URLQueryItem(name: "fields", value: "id")])
        )
        request.httpMethod = "POST"
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(metadata)
        return try decode(DriveFile.self, from: try await authorized(request, idempotent: false))
    }

    private func replaceContent(of id: String, with data: Data) async throws -> DriveFile {
        var request = URLRequest(
            url: Self.uploadAPI.appending(path: "files/\(id)").appending(queryItems: [
                URLQueryItem(name: "uploadType", value: "media"),
                URLQueryItem(name: "fields", value: "id,headRevisionId"),
            ])
        )
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        return try decode(DriveFile.self, from: try await authorized(request))
    }

    private func keepForever(fileId: String, revision: String) async throws {
        var request = URLRequest(
            url: Self.api.appending(path: "files/\(fileId)/revisions/\(revision)")
                .appending(queryItems: [URLQueryItem(name: "fields", value: "id")])
        )
        request.httpMethod = "PATCH"
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(#"{"keepForever":true}"#.utf8)
        _ = try await authorized(request)
    }

    // MARK: Requests

    /// Adds the bearer token (a header, never the URL). A 401 gets one retry with a fresh
    /// token, since the cached one may have been revoked or expired early.
    private func authorized(_ request: URLRequest, idempotent: Bool = true) async throws -> Data {
        var retried = false
        while true {
            var signed = request
            signed.setValue("Bearer \(try await tokens.accessToken())", forHTTPHeaderField: "Authorization")
            let (data, response) = try await transport.send(signed, idempotent: idempotent)
            if response.statusCode == 401, !retried {
                await tokens.invalidateAccessToken()
                retried = true
                continue
            }
            try HTTPTransport.check(response, body: data)
            return data
        }
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        guard let value = try? JSONDecoder().decode(type, from: data) else { throw RemoteStoreError.server(status: 0) }
        return value
    }
}

struct DriveFile: Decodable, Sendable {
    let id: String
    let headRevisionId: String?
}

private struct FileList: Decodable {
    let files: [DriveFile]
}

private struct RevisionPage: Decodable {
    struct Revision: Decodable {
        let id: String
    }

    let revisions: [Revision]
    let nextPageToken: String?
}

private struct FileMetadata: Encodable {
    let name: String
    let mimeType: String
    let parents: [String]?
    let appProperties: [String: String]
}

extension Data {
    fileprivate mutating func append(_ text: String) {
        append(Data(text.utf8))
    }
}
