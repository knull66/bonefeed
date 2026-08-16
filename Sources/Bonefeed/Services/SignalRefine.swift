import Foundation

/// Anti-flap hysteresis + regime digest for market pnl alerts.
enum SignalRefine {
    struct GateState: Codable, Sendable {
        /// Symbols that already fired dump and await reset.
        var dumpLatched: Set<String> = []
        /// Symbols that already fired pump and await reset.
        var pumpLatched: Set<String> = []
    }

    /// Reset band ≈ 72% of threshold magnitude (e.g. −2.5 → −1.8).
    static func dumpReset(threshold: Double) -> Double {
        threshold * 0.72
    }

    static func pumpReset(threshold: Double) -> Double {
        threshold * 0.72
    }

    /// Update latches from live ticks; returns whether a side may emit a fresh alert.
    static func allowFire(
        symbol: String,
        change24h: Double,
        dumpThreshold: Double,
        pumpThreshold: Double,
        antiFlap: Bool,
        state: inout GateState
    ) -> (side: String, fire: Bool)? {
        let sym = symbol.uppercased()

        if change24h <= dumpThreshold {
            if !antiFlap {
                return ("DUMP", true)
            }
            if state.dumpLatched.contains(sym) {
                return ("DUMP", false)
            }
            state.dumpLatched.insert(sym)
            state.pumpLatched.remove(sym)
            return ("DUMP", true)
        }

        if change24h >= pumpThreshold {
            if !antiFlap {
                return ("PUMP", true)
            }
            if state.pumpLatched.contains(sym) {
                return ("PUMP", false)
            }
            state.pumpLatched.insert(sym)
            state.dumpLatched.remove(sym)
            return ("PUMP", true)
        }

        // Recover → re-arm
        if antiFlap {
            if change24h > dumpReset(threshold: dumpThreshold) {
                state.dumpLatched.remove(sym)
            }
            if change24h < pumpReset(threshold: pumpThreshold) {
                state.pumpLatched.remove(sym)
            }
        }
        return nil
    }

    /// ≥3 dumps or ≥50% of board → one regime alert; drop per-coin dump alerts for notify.
    static func collapseRegime(
        alerts: [IslandAlert],
        signals: [MarketSignal],
        tickCount: Int,
        vipTag: String
    ) -> (alerts: [IslandAlert], signals: [MarketSignal], regime: Bool) {
        let dumpAlerts = alerts.filter { $0.kind == .pnl && $0.title.localizedCaseInsensitiveContains("dump") }
        let dumpSignals = signals.filter { $0.kind == .dump }
        let n = max(dumpAlerts.count, dumpSignals.count)
        let board = max(tickCount, 1)
        let broad = n >= 3 || Double(n) / Double(board) >= 0.5
        guard broad, n >= 2 else {
            return (alerts, signals, false)
        }

        let kept = alerts.filter { alert in
            !(alert.kind == .pnl && alert.title.localizedCaseInsensitiveContains("dump"))
        }
        let regime = IslandAlert(
            id: UUID(),
            kind: .pnl,
            title: "\(vipTag)\(L10n.t("signal.regimeDump"))",
            detail: String(format: L10n.t("signal.regimeDumpDetail"), n, board),
            createdAt: .now,
            isRead: false
        )
        var nextSignals = signals.filter { $0.kind != .dump }
        nextSignals.insert(
            MarketSignal(
                id: "regime-dump",
                kind: .dump,
                title: L10n.t("signal.regimeDump"),
                detail: String(format: L10n.t("signal.regimeDumpDetail"), n, board)
            ),
            at: 0
        )
        // Keep individual dump signals for heat board context (append after regime).
        nextSignals.append(contentsOf: dumpSignals)
        return (kept + [regime], nextSignals, true)
    }
}
