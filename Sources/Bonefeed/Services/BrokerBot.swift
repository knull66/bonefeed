import Foundation

/// Admin broker desk — live suggestions only. Never places orders.
enum BrokerBot {
    enum Stance: String {
        case hold
        case watchLong
        case watchShort
        case standAside
        case ops
        case fee
    }

    enum Action: String, CaseIterable {
        case openTrade
        case openP2P
        case openEarn
        case openSignals
        case dismiss
    }

    struct Suggestion: Identifiable {
        let id: String
        let stance: Stance
        let confidence: Int // 0…100
        let symbol: String?
        let titleKey: String
        let bodyKey: String
        var bodyArgs: [Any] = []
        let actions: [Action]
    }

    struct Snapshot {
        var dumpCount: Int
        var pumpCount: Int
        var feeHigh: Bool
        var tickCount: Int
        var hottestSymbol: String?
        var hottestChange: Double
        var hottestVolumeSpike: Double?
        var btcChange: Double
        var heatAvg: Double
        var quietHours: Bool
        var vipTight: Bool
        var openP2P: Bool
        var binanceConnected: Bool
        var regimeDump: Bool
    }

    static func suggestions(for snap: Snapshot) -> [Suggestion] {
        var out: [Suggestion] = []

        out.append(Suggestion(
            id: "mandate",
            stance: .ops,
            confidence: 100,
            symbol: nil,
            titleKey: "bot.mandate.title",
            bodyKey: "bot.mandate.body",
            actions: []
        ))

        if snap.openP2P {
            out.append(Suggestion(
                id: "p2p-live",
                stance: .ops,
                confidence: 95,
                symbol: nil,
                titleKey: "bot.p2pLive.title",
                bodyKey: "bot.p2pLive.body",
                actions: [.openP2P, .dismiss]
            ))
        }

        if snap.feeHigh {
            out.append(Suggestion(
                id: "fee",
                stance: .fee,
                confidence: 80,
                symbol: "BTC",
                titleKey: "bot.fee.title",
                bodyKey: "bot.fee.body",
                actions: [.openEarn, .dismiss]
            ))
        }

        let dumpShare = snap.tickCount > 0 ? Double(snap.dumpCount) / Double(snap.tickCount) : 0
        let broadDump = snap.regimeDump || snap.dumpCount >= 3 || dumpShare >= 0.5

        if broadDump {
            let conf = min(92, 55 + snap.dumpCount * 8)
            out.append(Suggestion(
                id: "broad-dump",
                stance: .standAside,
                confidence: conf,
                symbol: "BTC",
                titleKey: "bot.broadDump.title",
                bodyKey: "bot.broadDump.body",
                bodyArgs: [snap.dumpCount, snap.tickCount, String(format: "%+.1f", snap.btcChange)],
                actions: [.openTrade, .openSignals, .dismiss]
            ))
            out.append(Suggestion(
                id: "broad-dump-short",
                stance: .watchShort,
                confidence: max(40, conf - 15),
                symbol: snap.hottestSymbol,
                titleKey: "bot.broadDumpShort.title",
                bodyKey: "bot.broadDumpShort.body",
                actions: [.openTrade, .dismiss]
            ))
        } else if snap.dumpCount == 1, let sym = snap.hottestSymbol, snap.hottestChange < 0 {
            let volOK = (snap.hottestVolumeSpike ?? 0) >= 2.5
            out.append(Suggestion(
                id: "idio-dump",
                stance: volOK ? .watchShort : .standAside,
                confidence: volOK ? 68 : 48,
                symbol: sym,
                titleKey: volOK ? "bot.idioDumpVol.title" : "bot.idioDump.title",
                bodyKey: volOK ? "bot.idioDumpVol.body" : "bot.idioDump.body",
                bodyArgs: [sym, String(format: "%+.1f", snap.hottestChange)],
                actions: [.openTrade, .openSignals, .dismiss]
            ))
        }

        if snap.pumpCount >= 2 {
            out.append(Suggestion(
                id: "cluster-pump",
                stance: .standAside,
                confidence: 62,
                symbol: snap.hottestSymbol,
                titleKey: "bot.clusterPump.title",
                bodyKey: "bot.clusterPump.body",
                bodyArgs: [snap.pumpCount],
                actions: [.openTrade, .dismiss]
            ))
            out.append(Suggestion(
                id: "cluster-pump-long",
                stance: .watchLong,
                confidence: 45,
                symbol: snap.hottestSymbol,
                titleKey: "bot.clusterPumpLong.title",
                bodyKey: "bot.clusterPumpLong.body",
                actions: [.openTrade, .dismiss]
            ))
        } else if snap.pumpCount == 1, let sym = snap.hottestSymbol, snap.hottestChange > 0 {
            let volOK = (snap.hottestVolumeSpike ?? 0) >= 2.5
            out.append(Suggestion(
                id: "single-pump",
                stance: volOK ? .watchLong : .hold,
                confidence: volOK ? 58 : 40,
                symbol: sym,
                titleKey: volOK ? "bot.singlePumpVol.title" : "bot.singlePump.title",
                bodyKey: volOK ? "bot.singlePumpVol.body" : "bot.singlePump.body",
                bodyArgs: [sym, String(format: "%+.1f", snap.hottestChange)],
                actions: [.openTrade, .dismiss]
            ))
        }

        if snap.btcChange <= -2.5 && !broadDump {
            out.append(Suggestion(
                id: "btc-lead-down",
                stance: .watchShort,
                confidence: 60,
                symbol: "BTC",
                titleKey: "bot.btcLeadDown.title",
                bodyKey: "bot.btcLeadDown.body",
                bodyArgs: [String(format: "%+.1f", snap.btcChange)],
                actions: [.openTrade, .dismiss]
            ))
        } else if snap.btcChange >= 2.5 && snap.pumpCount == 0 {
            out.append(Suggestion(
                id: "btc-lead-up",
                stance: .watchLong,
                confidence: 55,
                symbol: "BTC",
                titleKey: "bot.btcLeadUp.title",
                bodyKey: "bot.btcLeadUp.body",
                bodyArgs: [String(format: "%+.1f", snap.btcChange)],
                actions: [.openTrade, .dismiss]
            ))
        }

        if snap.heatAvg >= 0.7 && snap.dumpCount == 0 && snap.pumpCount == 0 {
            out.append(Suggestion(
                id: "near",
                stance: .hold,
                confidence: 50,
                symbol: snap.hottestSymbol,
                titleKey: "bot.near.title",
                bodyKey: "bot.near.body",
                bodyArgs: [Int(snap.heatAvg * 100)],
                actions: [.openSignals, .dismiss]
            ))
        }

        if snap.dumpCount == 0 && snap.pumpCount == 0 && snap.heatAvg < 0.45 && !snap.openP2P && !snap.feeHigh {
            out.append(Suggestion(
                id: "calm",
                stance: .hold,
                confidence: 70,
                symbol: nil,
                titleKey: "bot.calm.title",
                bodyKey: "bot.calm.body",
                actions: [.openSignals]
            ))
        }

        if snap.quietHours {
            out.append(Suggestion(
                id: "quiet",
                stance: .standAside,
                confidence: 75,
                symbol: nil,
                titleKey: "bot.quiet.title",
                bodyKey: "bot.quiet.body",
                actions: [.dismiss]
            ))
        }

        if !snap.binanceConnected {
            out.append(Suggestion(
                id: "no-api",
                stance: .ops,
                confidence: 90,
                symbol: nil,
                titleKey: "bot.noApi.title",
                bodyKey: "bot.noApi.body",
                actions: []
            ))
        }

        if snap.vipTight && (snap.dumpCount + snap.pumpCount) >= 2 {
            out.append(Suggestion(
                id: "vip-noise",
                stance: .ops,
                confidence: 65,
                symbol: nil,
                titleKey: "bot.vipNoise.title",
                bodyKey: "bot.vipNoise.body",
                actions: [.openSignals, .dismiss]
            ))
        }

        // Deduplicate by id, keep mandate first, cap list.
        var seen = Set<String>()
        var unique: [Suggestion] = []
        for s in out where seen.insert(s.id).inserted {
            unique.append(s)
        }
        return Array(unique.prefix(8))
    }
}
