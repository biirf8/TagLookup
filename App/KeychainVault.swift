import Foundation
import Security

enum KeychainVault {
    private static var identity: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.brody.taglookup.session",
         kSecAttrAccount as String: "63FDD",
         kSecAttrSynchronizable as String: false]
    }

    static func read() throws -> String? {
        var query = identity
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let bytes = result as? Data,
              let value = String(data: bytes, encoding: .utf8) else { throw VaultError.failed }
        return value
    }

    static func write(_ ticket: String) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: Data(ticket.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let updated = SecItemUpdate(identity as CFDictionary, attributes as CFDictionary)
        if updated == errSecSuccess { return }
        guard updated == errSecItemNotFound else { throw VaultError.failed }
        let insertion = identity.merging(attributes) { _, new in new }
        guard SecItemAdd(insertion as CFDictionary, nil) == errSecSuccess else { throw VaultError.failed }
    }

    static func remove() throws {
        let status = SecItemDelete(identity as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw VaultError.failed }
    }

    enum VaultError: LocalizedError {
        case failed
        var errorDescription: String? { "Session storage is unavailable. Unlock your iPhone and try again." }
    }
}
