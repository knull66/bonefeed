import CryptoKit
import Foundation
import Security

/// Encrypted credential file (AES-GCM). Wrapping key lives in Keychain with
/// `AfterFirstUnlockThisDeviceOnly` + no interactive UI — safe for ad-hoc builds.
enum LocalCredentialStore {
    private static let fileName = "binance-credentials.sealed"
    private static let legacyFileName = "binance-credentials.json"
    private static let keychainService = "app.bonefeed.macos.binance.seal"
    private static let legacyKeychainService = "app.chainisland.macos.binance.seal"
    private static let keychainAccount = "aes-gcm-key"

    private struct PlainPayload: Codable {
        var apiKey: String
        var apiSecret: String
    }

    private struct SealedPayload: Codable {
        var nonce: Data
        var ciphertext: Data
    }

    private static var directoryURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return root.appendingPathComponent("Bonefeed", isDirectory: true)
    }

    private static var legacyDirectoryURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return root.appendingPathComponent("Chain Island", isDirectory: true)
    }

    private static var fileURL: URL {
        directoryURL.appendingPathComponent(fileName)
    }

    private static var legacyURL: URL {
        directoryURL.appendingPathComponent(legacyFileName)
    }

    private static var legacyBrandFileURL: URL {
        legacyDirectoryURL.appendingPathComponent(fileName)
    }

    private static var legacyBrandPlainURL: URL {
        legacyDirectoryURL.appendingPathComponent(legacyFileName)
    }

    static func save(apiKey: String, apiSecret: String) throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let key = try loadOrCreateSealKey()
        let plain = try JSONEncoder().encode(PlainPayload(apiKey: apiKey, apiSecret: apiSecret))
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(plain, using: key, nonce: nonce)
        let payload = SealedPayload(nonce: Data(nonce), ciphertext: sealed.ciphertext + sealed.tag)
        let data = try JSONEncoder().encode(payload)
        try data.write(to: fileURL, options: [.atomic])
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
        // Remove legacy plaintext if present.
        try? FileManager.default.removeItem(at: legacyURL)
    }

    static func load() -> BinanceCredentials? {
        if let sealed = loadSealed(from: fileURL) { return sealed }
        if let sealed = loadSealed(from: legacyBrandFileURL) {
            try? save(apiKey: sealed.apiKey, apiSecret: sealed.apiSecret)
            try? FileManager.default.removeItem(at: legacyBrandFileURL)
            return sealed
        }
        // One-shot migrate from plaintext JSON.
        if let legacy = loadLegacyPlaintext(from: legacyURL)
            ?? loadLegacyPlaintext(from: legacyBrandPlainURL) {
            try? save(apiKey: legacy.apiKey, apiSecret: legacy.apiSecret)
            return legacy
        }
        return nil
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: legacyURL)
        try? FileManager.default.removeItem(at: legacyBrandFileURL)
        try? FileManager.default.removeItem(at: legacyBrandPlainURL)
        deleteSealKey()
    }

    private static func loadSealed(from url: URL) -> BinanceCredentials? {
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(SealedPayload.self, from: data),
              let key = loadSealKey()
        else { return nil }
        do {
            let nonce = try AES.GCM.Nonce(data: payload.nonce)
            let cipher = Data(payload.ciphertext.dropLast(16))
            let tag = Data(payload.ciphertext.suffix(16))
            let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: cipher, tag: tag)
            let plain = try AES.GCM.open(box, using: key)
            let decoded = try JSONDecoder().decode(PlainPayload.self, from: plain)
            guard !decoded.apiKey.isEmpty, !decoded.apiSecret.isEmpty else { return nil }
            return BinanceCredentials(apiKey: decoded.apiKey, apiSecret: decoded.apiSecret)
        } catch {
            return nil
        }
    }

    private static func loadLegacyPlaintext(from url: URL) -> BinanceCredentials? {
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(PlainPayload.self, from: data),
              !payload.apiKey.isEmpty, !payload.apiSecret.isEmpty
        else { return nil }
        return BinanceCredentials(apiKey: payload.apiKey, apiSecret: payload.apiSecret)
    }

    private static func loadOrCreateSealKey() throws -> SymmetricKey {
        if let existing = loadSealKey() { return existing }
        let key = SymmetricKey(size: .bits256)
        try saveSealKey(key)
        return key
    }

    private static func loadSealKey() -> SymmetricKey? {
        if let key = loadSealKey(service: keychainService) { return key }
        if let key = loadSealKey(service: legacyKeychainService) {
            try? saveSealKey(key)
            deleteSealKey(service: legacyKeychainService)
            return key
        }
        return nil
    }

    private static func loadSealKey(service: String) -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUISkip
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return SymmetricKey(data: data)
    }

    private static func saveSealKey(_ key: SymmetricKey) throws {
        let data = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainStore.KeychainError.unhandled(status)
        }
    }

    private static func deleteSealKey() {
        deleteSealKey(service: keychainService)
        deleteSealKey(service: legacyKeychainService)
    }

    private static func deleteSealKey(service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}
