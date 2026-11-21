import Foundation
import Security

/// 凭据保存遵循平台策略：macOS 一律落系统钥匙串，不写入明文文件
enum Keychain {
    static let service = "com.remotepilot.macos"

    /// 进程内缓存：同一账号只真正访问一次钥匙串。
    /// 一次连接流程里 password(for:) 会被解析方案、凭据检查、拉起客户端等多次调用，
    /// 不缓存就会连续弹多次系统授权框。
    private static let lock = NSLock()
    private static var cache: [String: String] = [:]

    private static func cached(_ account: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return cache[account]
    }

    private static func setCache(_ value: String?, for account: String) {
        lock.lock()
        defer { lock.unlock() }
        cache[account] = value
    }

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
        let base = query(account: account)

        // 原地更新，不「先删后建」：删除重建会让系统记录在条目 ACL 上的「始终允许」一并失效，
        // 于是下次读取又弹一次授权框，表现为授权记不住。
        let updated = SecItemUpdate(
            base as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updated == errSecSuccess {
            setCache(secret, for: account)
            return true
        }
        guard updated == errSecItemNotFound else { return false }

        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else { return false }
        setCache(secret, for: account)
        return true
    }

    static func secret(account: String) -> String? {
        if let cached = cached(account) { return cached }
        var q = query(account: account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let text = String(data: data, encoding: .utf8) else { return nil }
        setCache(text, for: account)
        return text
    }

    static func remove(account: String) {
        SecItemDelete(query(account: account) as CFDictionary)
        setCache(nil, for: account)
    }

    static func exists(account: String) -> Bool { secret(account: account) != nil }

    // MARK: 账号键

    static func passwordAccount(_ assetID: UUID) -> String { "asset.\(assetID.uuidString).password" }
    static func keyPassphraseAccount(_ assetID: UUID) -> String { "asset.\(assetID.uuidString).keypassphrase" }
}
