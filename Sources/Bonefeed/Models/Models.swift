import Foundation

enum IslandStatus: String, Codable, Sendable {
    case idle
    case watching
    case alert
    case actionNeeded
    case error

    var label: String {
        switch self {
        case .idle: "Idle"
        case .watching: "Watching"
        case .alert: "Alert"
        case .actionNeeded: "Action"
        case .error: "Error"
        }
    }
}

enum ChainKind: String, Codable, Sendable, CaseIterable {
    case btc
    case eth
    case sol

    var title: String {
        switch self {
        case .btc: "BTC"
        case .eth: "ETH"
        case .sol: "SOL"
        }
    }

    var nativeSymbol: String { title }
}

struct WatchedWallet: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var label: String
    var address: String
    var chain: ChainKind

    var shortAddress: String {
        guard address.count > 12 else { return address }
        return "\(address.prefix(6))…\(address.suffix(4))"
    }

    static let binanceSample = WatchedWallet(
        id: UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!,
        label: "Binance BTC",
        address: "bc1pt8rsa5nhh7hwwmyshq3jlhuee58wgrsxju6me0z04jjg7jyu5pnq82a6el",
        chain: .btc
    )
}

struct WalletSnapshot: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var label: String
    var address: String
    var chain: String
    var balanceNative: Double
    var balanceUSD: Double
    var pnl24hPercent: Double
    var healthFactor: Double?
    var nativeSymbol: String
    var pendingNative: Double

    var shortAddress: String {
        guard address.count > 12 else { return address }
        return "\(address.prefix(6))…\(address.suffix(4))"
    }

    var nativeText: String {
        String(format: "%.6f %@", balanceNative, nativeSymbol)
    }

    var pendingText: String {
        String(format: "%.6f %@ pending", pendingNative, nativeSymbol)
    }

    var healthText: String? {
        guard let healthFactor else { return nil }
        return String(format: "HF %.2f", healthFactor)
    }
}

struct FeeSnapshot: Codable, Sendable, Equatable {
    var rate: Double
    var unit: String
    var level: FeeLevel
    var updatedAt: Date

    enum FeeLevel: String, Codable, Sendable {
        case low
        case normal
        case high
    }
}

enum DepositSource: String, Codable, Sendable {
    case onchain
    case binance
    case simulated
}

struct DepositEvent: Identifiable, Codable, Sendable, Equatable {
    let id: String
    var walletLabel: String
    var address: String
    var asset: String
    var amount: Double
    var usd: Double
    var confirmed: Bool
    var detectedAt: Date
    var source: DepositSource
    var statusText: String

    var isSimulated: Bool { source == .simulated }

    var title: String {
        switch source {
        case .binance:
            return confirmed ? L10n.t("deposit.binanceOk") : L10n.t("deposit.binancePending")
        case .onchain:
            return confirmed ? L10n.t("deposit.onchainOk") : L10n.t("deposit.onchainMem")
        case .simulated:
            return L10n.t("deposit.sim")
        }
    }

    var amountText: String {
        if amount >= 1 {
            return String(format: "%.4f %@", amount, asset)
        }
        return String(format: "%.8f %@", amount, asset)
    }
}

struct BinanceAssetHolding: Identifiable, Codable, Sendable, Equatable {
    var asset: String
    var amount: Double
    var usd: Double
    var wallet: String

    var id: String { "\(wallet)-\(asset)" }

    var amountText: String {
        if amount >= 1 {
            return String(format: "%.4f", amount)
        }
        return String(format: "%.8f", amount)
    }
}

struct EarnPosition: Identifiable, Codable, Sendable, Equatable {
    enum Kind: String, Codable, Sendable {
        case flexible
        case locked

        var label: String {
            switch self {
            case .flexible: "Flexible"
            case .locked: "Locked"
            }
        }
    }

    let id: String
    var kind: Kind
    var asset: String
    var amount: Double
    var usd: Double
    var aprPercent: Double?
    var productId: String?
    var yesterdayRewards: Double?
    var yesterdayRewardsUSD: Double?
    var cumulativeRewards: Double?
    var unlockDate: Date?

    var amountText: String {
        amount >= 1 ? String(format: "%.4f", amount) : String(format: "%.8f", amount)
    }

    var aprText: String? {
        guard let aprPercent else { return nil }
        return String(format: "%.2f%% APR", aprPercent)
    }

    var daysRemaining: Int? {
        guard let unlockDate else { return nil }
        let cal = Calendar.current
        return cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: .now),
            to: cal.startOfDay(for: unlockDate)
        ).day
    }

    var unlockText: String? {
        guard let daysRemaining else { return nil }
        if daysRemaining < 0 { return "Unlock overdue" }
        if daysRemaining == 0 { return "Unlock today" }
        if daysRemaining == 1 { return "Unlock tomorrow" }
        return "Unlock in \(daysRemaining)d"
    }
}

struct EarnAPROpportunity: Identifiable, Codable, Sendable, Equatable {
    var asset: String
    var currentAprPercent: Double
    var bestAprPercent: Double
    var bestProductId: String?
    var amountUSD: Double

    var id: String { asset }

    var gainPercent: Double { bestAprPercent - currentAprPercent }

    var detailText: String {
        String(
            format: "%@ · ahora %.2f%% → mejor %.2f%% (+%.2f)",
            asset,
            currentAprPercent,
            bestAprPercent,
            gainPercent
        )
    }
}

struct IslandAlert: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var kind: Kind
    var title: String
    var detail: String
    var createdAt: Date
    var isRead: Bool

    enum Kind: String, Codable, Sendable {
        case gas
        case health
        case pnl
        case whale
        case deposit
        case earn

        var symbol: String {
            switch self {
            case .gas: "flame.fill"
            case .health: "heart.fill"
            case .pnl: "chart.line.uptrend.xyaxis"
            case .whale: "water.waves"
            case .deposit: "arrow.down.circle.fill"
            case .earn: "leaf.fill"
            }
        }
    }
}

struct MarketSnapshot: Codable, Sendable, Equatable {
    var totalBalanceUSD: Double
    /// Prefer portfolio 24h when available; else market (BTC) change.
    var pnl24hPercent: Double
    var marketChange24hPercent: Double
    var portfolioPnL24hPercent: Double?
    var btcPriceUSD: Double
    var fee: FeeSnapshot
    var wallets: [WalletSnapshot]
    var alerts: [IslandAlert]
    var deposits: [DepositEvent]
    var status: IslandStatus
    var lastTick: Date
    var dataMode: String
    var statusDetail: String?
    var radarLabel: String
    var binanceBTC: Double
    var binanceBTCUSD: Double
    var binanceConnected: Bool
    var binanceStatus: String
    var binanceLiquidHoldings: [BinanceAssetHolding]
    var earnPositions: [EarnPosition]
    var earnOpportunities: [EarnAPROpportunity]
    var binancePortfolioUSD: Double
    var binanceEarnUSD: Double
    var earnYesterdayRewardsUSD: Double
    var earnStatus: String?
    var fundingStatus: String?
    var activeSignals: [MarketSignal]
    var marketTicks: [AssetTick]
    var userStreamLive: Bool

    var binanceHoldingsCount: Int {
        binanceLiquidHoldings.count + earnPositions.count
    }
}

struct AlertThresholds: Codable, Sendable, Equatable {
    var feeHigh: Double
    var pnlDropPercent: Double
    var pnlPumpPercent: Double
    var feeAlertsEnabled: Bool
    var pnlAlertsEnabled: Bool
    /// Empty = all watchlist assets.
    var signalAssets: [String]
    var cooldownMinutes: Int
    var quietHoursEnabled: Bool
    var quietHoursStart: Int
    var quietHoursEnd: Int
    var healthAlertsEnabled: Bool
    var healthFactorWarn: Double

    static let `default` = AlertThresholds(
        feeHigh: 40,
        pnlDropPercent: -5,
        pnlPumpPercent: 5,
        feeAlertsEnabled: false,
        pnlAlertsEnabled: true,
        signalAssets: [],
        cooldownMinutes: 30,
        quietHoursEnabled: false,
        quietHoursStart: 23,
        quietHoursEnd: 8,
        healthAlertsEnabled: true,
        healthFactorWarn: 1.5
    )

    init(
        feeHigh: Double,
        pnlDropPercent: Double,
        pnlPumpPercent: Double,
        feeAlertsEnabled: Bool,
        pnlAlertsEnabled: Bool,
        signalAssets: [String],
        cooldownMinutes: Int,
        quietHoursEnabled: Bool,
        quietHoursStart: Int,
        quietHoursEnd: Int,
        healthAlertsEnabled: Bool,
        healthFactorWarn: Double
    ) {
        self.feeHigh = feeHigh
        self.pnlDropPercent = pnlDropPercent
        self.pnlPumpPercent = pnlPumpPercent
        self.feeAlertsEnabled = feeAlertsEnabled
        self.pnlAlertsEnabled = pnlAlertsEnabled
        self.signalAssets = signalAssets
        self.cooldownMinutes = cooldownMinutes
        self.quietHoursEnabled = quietHoursEnabled
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.healthAlertsEnabled = healthAlertsEnabled
        self.healthFactorWarn = healthFactorWarn
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        feeHigh = try c.decodeIfPresent(Double.self, forKey: .feeHigh) ?? Self.default.feeHigh
        pnlDropPercent = try c.decodeIfPresent(Double.self, forKey: .pnlDropPercent) ?? Self.default.pnlDropPercent
        pnlPumpPercent = try c.decodeIfPresent(Double.self, forKey: .pnlPumpPercent) ?? Self.default.pnlPumpPercent
        feeAlertsEnabled = try c.decodeIfPresent(Bool.self, forKey: .feeAlertsEnabled) ?? Self.default.feeAlertsEnabled
        pnlAlertsEnabled = try c.decodeIfPresent(Bool.self, forKey: .pnlAlertsEnabled) ?? Self.default.pnlAlertsEnabled
        signalAssets = try c.decodeIfPresent([String].self, forKey: .signalAssets) ?? Self.default.signalAssets
        cooldownMinutes = try c.decodeIfPresent(Int.self, forKey: .cooldownMinutes) ?? Self.default.cooldownMinutes
        quietHoursEnabled = try c.decodeIfPresent(Bool.self, forKey: .quietHoursEnabled) ?? Self.default.quietHoursEnabled
        quietHoursStart = try c.decodeIfPresent(Int.self, forKey: .quietHoursStart) ?? Self.default.quietHoursStart
        quietHoursEnd = try c.decodeIfPresent(Int.self, forKey: .quietHoursEnd) ?? Self.default.quietHoursEnd
        healthAlertsEnabled = try c.decodeIfPresent(Bool.self, forKey: .healthAlertsEnabled) ?? Self.default.healthAlertsEnabled
        healthFactorWarn = try c.decodeIfPresent(Double.self, forKey: .healthFactorWarn) ?? Self.default.healthFactorWarn
    }

    func allowsSignal(for symbol: String) -> Bool {
        guard !signalAssets.isEmpty else { return true }
        return signalAssets.contains(symbol.uppercased())
    }

    func isInQuietHours(at date: Date = .now) -> Bool {
        guard quietHoursEnabled else { return false }
        let hour = Calendar.current.component(.hour, from: date)
        if quietHoursStart == quietHoursEnd { return false }
        if quietHoursStart < quietHoursEnd {
            return hour >= quietHoursStart && hour < quietHoursEnd
        }
        // Wraps midnight: e.g. 23 → 8
        return hour >= quietHoursStart || hour < quietHoursEnd
    }
}

struct MarketSignal: Identifiable, Codable, Sendable, Equatable {
    enum Kind: String, Codable, Sendable {
        case calm
        case dump
        case pump
        case feeHigh
        case health

        var label: String {
            switch self {
            case .calm: "Calm"
            case .dump: "Dump"
            case .pump: "Pump"
            case .feeHigh: "Fees"
            case .health: "Health"
            }
        }
    }

    let id: String
    var kind: Kind
    var title: String
    var detail: String
}

struct AssetTick: Identifiable, Codable, Sendable, Equatable {
    var symbol: String
    var priceUSD: Double
    var change24hPercent: Double

    var id: String { symbol }

    var priceText: String {
        if priceUSD >= 1000 {
            return String(format: "$%.0f", priceUSD)
        }
        if priceUSD >= 1 {
            return String(format: "$%.2f", priceUSD)
        }
        return String(format: "$%.4f", priceUSD)
    }

    var changeText: String {
        String(format: "%+.2f%%", change24hPercent)
    }
}

enum RadarWatchlist {
    static let presets = ["BTC", "ETH", "SOL", "BNB", "XRP", "DOGE", "AVAX", "LINK", "SUI", "PEPE", "ADA", "DOT"]
    static let `default` = ["BTC", "ETH", "SOL"]
    /// No *USDT spot pair — including these breaks Binance batch ticker.
    static let nonTickerBases: Set<String> = [
        "USDT", "USDC", "BUSD", "FDUSD", "TUSD", "DAI", "USDP", "USD1", "USD"
    ]

    static func sanitize(_ assets: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for raw in assets {
            let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !s.isEmpty, s.count <= 12 else { continue }
            guard !nonTickerBases.contains(s) else { continue }
            guard seen.insert(s).inserted else { continue }
            out.append(s)
        }
        return out.isEmpty ? `default` : Array(out.prefix(16))
    }
}
