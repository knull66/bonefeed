import Foundation

/// Local VIP ping history — early-warning log, not predictions.
enum SignalHistoryStore {
    private static let key = "bonefeed.signalHistory.v1"
    private static let maxEntries = 60

    struct Ping: Identifiable, Codable, Sendable, Equatable {
        var id: String
        var kind: String
        var title: String
        var detail: String
        var at: Date
    }

    static func load() -> [Ping] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let items = try? JSONDecoder().decode([Ping].self, from: data)
        else { return [] }
        return items.sorted { $0.at > $1.at }
    }

    static func append(_ ping: Ping, into items: inout [Ping]) {
        if items.contains(where: { $0.id == ping.id }) { return }
        items.insert(ping, at: 0)
        if items.count > maxEntries {
            items = Array(items.prefix(maxEntries))
        }
        persist(items)
    }

    static func append(
        kind: String,
        title: String,
        detail: String,
        signature: String,
        into items: inout [Ping]
    ) {
        let ping = Ping(
            id: "\(signature)|\(Int(Date().timeIntervalSince1970))",
            kind: kind,
            title: title,
            detail: detail,
            at: Date()
        )
        append(ping, into: &items)
    }

    static func clear(into items: inout [Ping]) {
        items = []
        UserDefaults.standard.removeObject(forKey: key)
    }

    private static func persist(_ items: [Ping]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
