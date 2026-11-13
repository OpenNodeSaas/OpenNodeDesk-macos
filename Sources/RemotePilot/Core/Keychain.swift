import Foundation
import Security

/// 凭据保存遵循平台策略：macOS 一律落系统钥匙串，不写入明文文件
enum Keychain {
    static let service = "com.remotepilot.macos"

    private static func query(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    @discardableResult
    static func store(_ secret: String, account: String) -> Bool {
        let data = Data(secret.utf8)
        var base = query(account: account)
        SecItemDelete(base as CFDictionary)
        base[kSecValueData as String] = data
        base[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(base as CFDictionary, nil) == errSecSuccess
    }

    static func secret(account: String) -> String? {
        var q = query(account: account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let text = String(data: data, encoding: .utf8) else { return nil }
        return text
    }

    static func remove(account: String) {
        SecItemDelete(query(account: account) as CFDictionary)
    }

    static func exists(account: String) -> Bool { secret(account: account) != nil }

    // MARK: 账号键

    static func passwordAccount(_ assetID: UUID) -> String { "asset.\(assetID.uuidString).password" }
    static func keyPassphraseAccount(_ assetID: UUID) -> String { "asset.\(assetID.uuidString).keypassphrase" }
}
