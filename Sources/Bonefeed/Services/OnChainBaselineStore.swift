import Foundation

/// Persists on-chain funded/balance baselines so deposits survive app restarts.
enum OnChainBaselineStore {
    private static let key = "bonefeed.onchainBaselines.v1"

    struct Record: Codable, Sendable {
        /// Smallest-unit or native baseline (BTC sats as decimal string, ETH wei, SOL lamports).
        var amount: String
        var unit: String
        var updatedAt: Date
    }

    static func load() -> [String: Record] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: Record].self, from: data)
        else { return [:] }
        return decoded
    }

    static func save(_ map: [String: Record]) {
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
