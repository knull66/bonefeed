import Foundation
import Security

enum KeychainStore {
    private static let service = "app.bonefeed.macos.binance"
    private static let legacyService = "app.chainisland.macos.binance"

    enum Key: String {
        case apiKey = "binance.apiKey"
        case apiSecret = "binance.apiSecret"
    }

    static func save(_ value: String, for key: Key) throws {
        let data = Data(value.utf8)
        // Clear both namespaces so old entries don't linger.
        delete(key, service: service)
        delete(key, service: legacyService)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }
    }

    static func load(_ key: Key) -> String? {
        if let value = load(key, service: service, interactive: false) { return value }
        if let value = load(key, service: legacyService, interactive: false) {
            try? save(value, for: key)
            return value
        }
        return nil
    }

    /// One interactive read (may show Keychain prompt once).
    static func loadInteractive(_ key: Key) -> String? {
        if let value = load(key, service: service, interactive: true) { return value }
        if let value = load(key, service: legacyService, interactive: true) {
            try? save(value, for: key)
            return value
        }
        return nil
    }

    static func delete(_ key: Key) {
        delete(key, service: service)
        delete(key, service: legacyService)
    }

    static func clearBinanceCredentials() {
        delete(.apiKey)
        delete(.apiSecret)
    }

    private static func load(_ key: Key, service: String, interactive: Bool) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if !interactive {
            query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip
        }
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(_ key: Key, service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }

    enum KeychainError: Error {
        case unhandled(OSStatus)
    }
}
