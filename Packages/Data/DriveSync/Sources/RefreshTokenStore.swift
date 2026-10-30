import Domain
import Foundation
import Security

/// Where the Google refresh token lives between launches.
protocol RefreshTokenStore: Sendable {
    func load() -> String?
    func save(_ token: String) throws
    func delete()
}

/// The refresh token in the data protection keychain: this Mac only, never synced, readable
/// only while the Mac is unlocked, and without a prompt, because sync runs in the background.
/// It grants access only to the app's own Drive files.
struct KeychainRefreshTokenStore: RefreshTokenStore {
    private let service: String

    init(service: String = "Tenure.googleDrive") {
        self.service = service
    }

    func load() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func save(_ token: String) throws {
        delete()
        var attributes = baseQuery
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        attributes[kSecAttrLabel as String] = "Tenure Google Drive sign-in"
        attributes[kSecValueData as String] = Data(token.utf8)
        guard SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess else {
            throw DriveSignInError.failed
        }
    }

    func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "refresh-token",
            kSecUseDataProtectionKeychain as String: true,
            kSecAttrSynchronizable as String: false,
        ]
    }
}
