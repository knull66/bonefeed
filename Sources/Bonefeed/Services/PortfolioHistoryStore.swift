import Foundation

/// Rolling portfolio USD samples for real 24h PnL (not market ticker %).
enum PortfolioHistoryStore {
    private static let key = "bonefeed.portfolioHistory.v1"
    private static let maxAge: TimeInterval = 60 * 60 * 36
    private static let minGap: TimeInterval = 60

    struct Sample: Codable, Sendable {
        var at: Date
        var usd: Double
    }

    static func load() -> [Sample] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let samples = try? JSONDecoder().decode([Sample].self, from: data)
        else { return [] }
        return prune(samples)
    }

    static func record(usd: Double, into samples: inout [Sample]) {
        guard usd > 0 else { return }
        let now = Date()
        if let last = samples.last, now.timeIntervalSince(last.at) < minGap {
            samples[samples.count - 1] = Sample(at: now, usd: usd)
        } else {
            samples.append(Sample(at: now, usd: usd))
        }
        samples = prune(samples)
        if let data = try? JSONEncoder().encode(samples) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Percent change vs sample closest to 24h ago. Nil until history exists.
    static func change24hPercent(currentUSD: Double, samples: [Sample]) -> Double? {
        guard currentUSD > 0, !samples.isEmpty else { return nil }
        let target = Date().addingTimeInterval(-24 * 60 * 60)
        guard let baseline = samples.min(by: {
            abs($0.at.timeIntervalSince(target)) < abs($1.at.timeIntervalSince(target))
        }) else { return nil }
        // Need at least ~6h of history to call it "24h-ish".
        guard Date().timeIntervalSince(baseline.at) >= 6 * 60 * 60, baseline.usd > 0 else {
            return nil
        }
        return ((currentUSD - baseline.usd) / baseline.usd) * 100
    }

    private static func prune(_ samples: [Sample]) -> [Sample] {
        let cutoff = Date().addingTimeInterval(-maxAge)
        return samples.filter { $0.at >= cutoff }
    }
}
