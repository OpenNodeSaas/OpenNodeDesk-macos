import Foundation
import CommonCrypto
import Security

/// 保护口令 / 恢复口令的哈希工具：PBKDF2-SHA256 + 随机盐 + 固定迭代次数。
/// 只保存盐与哈希（Base64），不保存明文；恢复口令的哈希基于「归一化后」的字符串。
enum ProtectionHasher {
    static let iterations = 100_000
    static let keyLength = 32          // SHA-256 输出长度
    static let saltLength = 16

    /// Crockford Base32 字符表（去掉易混的 I / L / O / U），仅用于生成可读的恢复口令
    private static let recoveryAlphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
    private static let recoveryGroups = 4
    private static let recoveryGroupLength = 5

    // MARK: - 盐与派生

    static func makeSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: saltLength)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
            for index in bytes.indices { bytes[index] = UInt8.random(in: 0...255) }
        }
        return Data(bytes)
    }

    /// 口令为空或盐为空时返回空串（调用方据此判定失败），不抛异常
    static func derive(password: String, salt: Data) -> Data {
        let passwordBytes = Array(password.utf8)
        guard !passwordBytes.isEmpty, !salt.isEmpty else { return Data() }

        var derived = [UInt8](repeating: 0, count: keyLength)
        let status: Int32 = derived.withUnsafeMutableBufferPointer { out in
            passwordBytes.withUnsafeBufferPointer { pw in
                salt.withUnsafeBytes { saltBuffer in
                    let pwPtr = pw.baseAddress?.withMemoryRebound(to: Int8.self, capacity: passwordBytes.count) { $0 }
                    let saltPtr = saltBuffer.bindMemory(to: UInt8.self).baseAddress
                    return CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        pwPtr, passwordBytes.count,
                        saltPtr, salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        out.baseAddress, out.count
                    )
                }
            }
        }
        return status == kCCSuccess ? Data(derived) : Data()
    }

    // MARK: - 生成与校验

    static func create(_ secret: String) -> (salt: String, hash: String) {
        let salt = makeSalt()
        let hash = derive(password: secret, salt: salt)
        return (salt.base64EncodedString(), hash.base64EncodedString())
    }

    /// 盐 / 哈希缺失或非法一律返回 false，不抛异常
    static func verify(_ secret: String, saltBase64: String, hashBase64: String) -> Bool {
        guard let salt = Data(base64Encoded: saltBase64),
              let expected = Data(base64Encoded: hashBase64),
              !salt.isEmpty, !expected.isEmpty else { return false }
        let actual = derive(password: secret, salt: salt)
        guard !actual.isEmpty else { return false }
        return constantTimeEquals(actual, expected)
    }

    private static func constantTimeEquals(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for index in a.indices { diff |= a[index] ^ b[index] }
        return diff == 0
    }

    // MARK: - 恢复口令

    /// 生成 20 位恢复口令，按 4 组 × 5 位用 "-" 分隔，如 K7M29-QPT4B-3VH8L-ZR6WX
    static func makeRecoveryCode() -> String {
        let count = recoveryGroups * recoveryGroupLength
        let indices = randomAlphabetIndices(count)
        let characters = indices.map { recoveryAlphabet[$0] }
        return stride(from: 0, to: count, by: recoveryGroupLength)
            .map { String(characters[$0..<min($0 + recoveryGroupLength, count)]) }
            .joined(separator: "-")
    }

    /// 校验前归一化：去空格/连字符、转大写、O→0、I/L→1（容忍用户抄写误差）
    static func normalizeRecoveryCode(_ code: String) -> String {
        var result = String()
        for character in code.uppercased() {
            switch character {
            case "O": result.append("0")
            case "I", "L": result.append("1")
            case "-", " ", "\t", "\n", "\r": continue
            default:
                if character.isLetter || character.isNumber { result.append(character) }
            }
        }
        return result
    }

    /// 字符表恰好 32 项，256 % 32 == 0，故 `byte % 32` 为无偏取模
    private static func randomAlphabetIndices(_ count: Int) -> [Int] {
        var bytes = [UInt8](repeating: 0, count: count)
        guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else {
            return (0..<count).map { _ in Int.random(in: 0..<recoveryAlphabet.count) }
        }
        return bytes.map { Int($0) % recoveryAlphabet.count }
    }
}
