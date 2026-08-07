import Foundation

struct RadarPollResult: Sendable {
    var snapshot: MarketSnapshot
    var newDeposits: [DepositEvent]
}

actor BitcoinMarketService {
    private let session: URLSession
    private let aave = AaveHealthService()
    private var cachedPriceUSD: Double = 0
    private var cachedChange24h: Double = 0
    private var lastPriceFetch: Date = .distantPast

    /// address(lower) -> baseline amount string (sats / wei / lamports)
    private var fundedBaseline: [String: String] = [:]
    private var primedAddresses: Set<String> = []
    private var baselinesLoaded = false

    init(session: URLSession = LiveURLSession.shared) {
        self.session = session
    }

    func fetchRadar(
        wallets: [WatchedWallet],
        thresholds: AlertThresholds,
        watchAssets: [String]
    ) async -> RadarPollResult {
        loadBaselinesIfNeeded()

        do {
            let assets = normalizedAssets(watchAssets)
            async let fees = fetchFees()
            async let ticksTask = fetchMarketTicks(assets)
            let feeRate = try await fees
            let ticks = await ticksTask
            let priceUSD = ticks.first(where: { $0.symbol == "BTC" })?.priceUSD
                ?? ticks.first?.priceUSD
                ?? cachedPriceUSD
            let change24h = ticks.first(where: { $0.symbol == "BTC" })?.change24hPercent
                ?? ticks.first?.change24hPercent
                ?? cachedChange24h
            if priceUSD > 0 {
                cachedPriceUSD = priceUSD
                cachedChange24h = change24h
                lastPriceFetch = .now
            }

            let ethPrice = ticks.first(where: { $0.symbol == "ETH" })?.priceUSD ?? 0
            let solPrice = ticks.first(where: { $0.symbol == "SOL" })?.priceUSD ?? 0

            var snapshots: [WalletSnapshot] = []
            var newDeposits: [DepositEvent] = []
            var alerts: [IslandAlert] = []
            var baselinesDirty = false

            for wallet in wallets {
                switch wallet.chain {
                case .btc:
                    let result = try await pollBTC(
                        wallet: wallet,
                        priceUSD: priceUSD,
                        change24h: change24h
                    )
                    snapshots.append(result.snapshot)
                    newDeposits.append(contentsOf: result.deposits)
                    alerts.append(contentsOf: result.alerts)
                    if result.baselineChanged { baselinesDirty = true }
                case .eth:
                    let result = await pollETH(
                        wallet: wallet,
                        priceUSD: ethPrice,
                        change24h: ticks.first(where: { $0.symbol == "ETH" })?.change24hPercent ?? 0,
                        thresholds: thresholds
                    )
                    snapshots.append(result.snapshot)
                    newDeposits.append(contentsOf: result.deposits)
                    alerts.append(contentsOf: result.alerts)
                    if result.baselineChanged { baselinesDirty = true }
                case .sol:
                    let result = await pollSOL(
                        wallet: wallet,
                        priceUSD: solPrice,
                        change24h: ticks.first(where: { $0.symbol == "SOL" })?.change24hPercent ?? 0
                    )
                    snapshots.append(result.snapshot)
                    newDeposits.append(contentsOf: result.deposits)
                    alerts.append(contentsOf: result.alerts)
                    if result.baselineChanged { baselinesDirty = true }
                }
            }

            if baselinesDirty {
                persistBaselines()
            }

            let feeLevel: FeeSnapshot.FeeLevel = {
                if feeRate >= thresholds.feeHigh { return .high }
                if feeRate <= 5 { return .low }
                return .normal
            }()

            var signals: [MarketSignal] = []

            if thresholds.feeAlertsEnabled, feeLevel == .high {
                let signal = MarketSignal(
                    id: "fee-high",
                    kind: .feeHigh,
                    title: L10n.t("signal.feesHigh"),
                    detail: String(format: "%.0f sat/vB", feeRate)
                )
                signals.append(signal)
                alerts.append(
                    IslandAlert(
                        id: UUID(),
                        kind: .gas,
                        title: L10n.t("signal.btcFees"),
                        detail: signal.detail,
                        createdAt: .now,
                        isRead: false
                    )
                )
            }

            if thresholds.pnlAlertsEnabled {
                for tick in ticks where thresholds.allowsSignal(for: tick.symbol) {
                    if tick.change24hPercent <= thresholds.pnlDropPercent {
                        let signal = MarketSignal(
                            id: "\(tick.symbol.lowercased())-dump",
                            kind: .dump,
                            title: "\(tick.symbol) \(L10n.t("signal.dump"))",
                            detail: String(format: "%+.2f%% (≤ %.0f%%)", tick.change24hPercent, thresholds.pnlDropPercent)
                        )
                        signals.append(signal)
                        alerts.append(
                            IslandAlert(
                                id: UUID(),
                                kind: .pnl,
                                title: String(format: L10n.t("signal.signalDump"), tick.symbol),
                                detail: signal.detail,
                                createdAt: .now,
                                isRead: false
                            )
                        )
                    } else if tick.change24hPercent >= thresholds.pnlPumpPercent {
                        let signal = MarketSignal(
                            id: "\(tick.symbol.lowercased())-pump",
                            kind: .pump,
                            title: "\(tick.symbol) \(L10n.t("signal.pump"))",
                            detail: String(format: "%+.2f%% (≥ +%.0f%%)", tick.change24hPercent, thresholds.pnlPumpPercent)
                        )
                        signals.append(signal)
                        alerts.append(
                            IslandAlert(
                                id: UUID(),
                                kind: .pnl,
                                title: String(format: L10n.t("signal.signalPump"), tick.symbol),
                                detail: signal.detail,
                                createdAt: .now,
                                isRead: false
                            )
                        )
                    }
                }
            }

            for snap in snapshots {
                if let hf = snap.healthFactor, thresholds.healthAlertsEnabled, hf < thresholds.healthFactorWarn {
                    let signal = MarketSignal(
                        id: "health-\(snap.id.uuidString)",
                        kind: .health,
                        title: L10n.t("signal.healthLow"),
                        detail: String(format: "%@ HF %.2f (<%.2f)", snap.label, hf, thresholds.healthFactorWarn)
                    )
                    if !signals.contains(where: { $0.id == signal.id }) {
                        signals.append(signal)
                    }
                    alerts.append(
                        IslandAlert(
                            id: UUID(),
                            kind: .health,
                            title: L10n.t("signal.aaveRisk"),
                            detail: signal.detail,
                            createdAt: .now,
                            isRead: false
                        )
                    )
                }
            }

            if signals.isEmpty {
                let summary = ticks.prefix(3).map { String(format: "%@ %+.1f%%", $0.symbol, $0.change24hPercent) }.joined(separator: " · ")
                signals.append(
                    MarketSignal(
                        id: "calm",
                        kind: .calm,
                        title: L10n.t("signal.calm"),
                        detail: summary.isEmpty
                            ? String(format: "fee %.0f sat", feeRate)
                            : "\(summary) · fee \(String(format: "%.0f", feeRate)) sat"
                    )
                )
            }

            let hasPending = snapshots.contains { $0.pendingNative > 0 }
            let hasHealthRisk = snapshots.contains {
                if let hf = $0.healthFactor { return hf < thresholds.healthFactorWarn }
                return false
            }
            let status: IslandStatus = {
                if !newDeposits.isEmpty { return .actionNeeded }
                if hasPending || hasHealthRisk { return .alert }
                if signals.contains(where: { $0.kind != .calm }) { return .alert }
                return .watching
            }()

            let detail: String? = {
                if hasHealthRisk {
                    return L10n.t("status.healthLow")
                }
                if hasPending {
                    return L10n.t("status.pendingBtc")
                }
                if snapshots.allSatisfy({ $0.balanceNative == 0 }) {
                    return L10n.t("status.zeroOnchain")
                }
                return L10n.t("status.listening")
            }()

            let snap = emptySnapshotBase(
                totalBalanceUSD: snapshots.reduce(0) { $0 + $1.balanceUSD },
                marketChange24h: change24h,
                priceUSD: priceUSD,
                feeRate: feeRate,
                feeLevel: feeLevel,
                wallets: snapshots,
                alerts: alerts,
                deposits: newDeposits,
                status: status,
                statusDetail: detail,
                radarLabel: hasPending
                    ? RadarCode.incoming
                    : (newDeposits.isEmpty ? RadarCode.ok : RadarCode.deposit),
                signals: signals,
                ticks: ticks
            )
            return RadarPollResult(snapshot: snap, newDeposits: newDeposits)
        } catch {
            let snap = emptySnapshotBase(
                totalBalanceUSD: 0,
                marketChange24h: cachedChange24h,
                priceUSD: cachedPriceUSD,
                feeRate: 0,
                feeLevel: .normal,
                wallets: [],
                alerts: [
                    IslandAlert(
                        id: UUID(),
                        kind: .whale,
                        title: L10n.t("signal.radarOffline"),
                        detail: error.localizedDescription,
                        createdAt: .now,
                        isRead: false
                    )
                ],
                deposits: [],
                status: .error,
                statusDetail: error.localizedDescription,
                radarLabel: RadarCode.error,
                signals: [],
                ticks: []
            )
            return RadarPollResult(snapshot: snap, newDeposits: [])
        }
    }

    func simulateDeposit(wallets: [WatchedWallet], priceUSD: Double) -> DepositEvent {
        let wallet = wallets.first ?? .binanceSample
        let amount = wallet.chain == .btc ? 0.0015 : (wallet.chain == .eth ? 0.05 : 0.5)
        let px: Double = {
            switch wallet.chain {
            case .btc: priceUSD > 0 ? priceUSD : 64000
            case .eth: 3000
            case .sol: 150
            }
        }()
        return DepositEvent(
            id: "sim-\(UUID().uuidString)",
            walletLabel: wallet.label,
            address: wallet.address,
            asset: wallet.chain.nativeSymbol,
            amount: amount,
            usd: amount * px,
            confirmed: false,
            detectedAt: .now,
            source: .simulated,
            statusText: "Simulated"
        )
    }

    // MARK: - Chain pollers

    private struct ChainPoll {
        var snapshot: WalletSnapshot
        var deposits: [DepositEvent]
        var alerts: [IslandAlert]
        var baselineChanged: Bool
    }

    private func pollBTC(wallet: WatchedWallet, priceUSD: Double, change24h: Double) async throws -> ChainPoll {
        let stats = try await fetchAddressStats(address: wallet.address)
        let confirmedSats = stats.chainFunded - stats.chainSpent
        let pendingSats = max(0, stats.memFunded - stats.memSpent)
        let totalFunded = stats.chainFunded + stats.memFunded
        let btc = Double(confirmedSats) / 100_000_000
        let pendingBTC = Double(pendingSats) / 100_000_000
        let key = baselineKey(wallet)
        let current = String(totalFunded)

        var deposits: [DepositEvent] = []
        var alerts: [IslandAlert] = []
        var dirty = false

        if !primedAddresses.contains(key) {
            fundedBaseline[key] = current
            primedAddresses.insert(key)
            dirty = true
        } else {
            let previous = Int64(fundedBaseline[key] ?? current) ?? totalFunded
            if totalFunded > previous {
                let delta = totalFunded - previous
                let deltaBTC = Double(delta) / 100_000_000
                let pendingDeltaLikely = pendingSats > 0
                    && Double(pendingSats) / 100_000_000 >= deltaBTC * 0.99
                let event = DepositEvent(
                    id: "\(key)-\(totalFunded)-\(Int(Date().timeIntervalSince1970))",
                    walletLabel: wallet.label,
                    address: wallet.address,
                    asset: "BTC",
                    amount: deltaBTC,
                    usd: deltaBTC * priceUSD,
                    confirmed: !pendingDeltaLikely,
                    detectedAt: .now,
                    source: .onchain,
                    statusText: pendingDeltaLikely ? "Mempool" : "Confirmed"
                )
                deposits.append(event)
                alerts.append(
                    IslandAlert(
                        id: UUID(),
                        kind: .deposit,
                        title: event.title,
                        detail: "\(wallet.label) +\(event.amountText) (≈ $\(String(format: "%.2f", event.usd)))",
                        createdAt: .now,
                        isRead: false
                    )
                )
            }
            if fundedBaseline[key] != current {
                fundedBaseline[key] = current
                dirty = true
            }
        }

        return ChainPoll(
            snapshot: WalletSnapshot(
                id: wallet.id,
                label: wallet.label,
                address: wallet.address,
                chain: "BTC",
                balanceNative: btc,
                balanceUSD: btc * priceUSD,
                pnl24hPercent: change24h,
                healthFactor: nil,
                nativeSymbol: "BTC",
                pendingNative: pendingBTC
            ),
            deposits: deposits,
            alerts: alerts,
            baselineChanged: dirty
        )
    }

    private func pollETH(
        wallet: WatchedWallet,
        priceUSD: Double,
        change24h: Double,
        thresholds: AlertThresholds
    ) async -> ChainPoll {
        let wei = (try? await fetchETHBalanceWei(address: wallet.address)) ?? "0"
        let eth = weiToEther(wei)
        let key = baselineKey(wallet)
        var deposits: [DepositEvent] = []
        var alerts: [IslandAlert] = []
        var dirty = false

        if !primedAddresses.contains(key) {
            fundedBaseline[key] = wei
            primedAddresses.insert(key)
            dirty = true
        } else {
            let previous = fundedBaseline[key] ?? wei
            if compareNumericString(wei, previous) > 0 {
                let delta = subtractNumericString(wei, previous)
                let deltaETH = weiToEther(delta)
                if deltaETH >= 0.00005 {
                    let event = DepositEvent(
                        id: "\(key)-\(wei.suffix(12))-\(Int(Date().timeIntervalSince1970))",
                        walletLabel: wallet.label,
                        address: wallet.address,
                        asset: "ETH",
                        amount: deltaETH,
                        usd: deltaETH * priceUSD,
                        confirmed: true,
                        detectedAt: .now,
                        source: .onchain,
                        statusText: "Confirmed"
                    )
                    deposits.append(event)
                    alerts.append(
                        IslandAlert(
                            id: UUID(),
                            kind: .deposit,
                            title: event.title,
                            detail: "\(wallet.label) +\(event.amountText) (≈ $\(String(format: "%.2f", event.usd)))",
                            createdAt: .now,
                            isRead: false
                        )
                    )
                }
            }
            if fundedBaseline[key] != wei {
                fundedBaseline[key] = wei
                dirty = true
            }
        }

        var health: Double?
        if thresholds.healthAlertsEnabled {
            health = await aave.fetchHealthFactor(address: wallet.address)
        }

        return ChainPoll(
            snapshot: WalletSnapshot(
                id: wallet.id,
                label: wallet.label,
                address: wallet.address,
                chain: "ETH",
                balanceNative: eth,
                balanceUSD: eth * priceUSD,
                pnl24hPercent: change24h,
                healthFactor: health,
                nativeSymbol: "ETH",
                pendingNative: 0
            ),
            deposits: deposits,
            alerts: alerts,
            baselineChanged: dirty
        )
    }

    private func pollSOL(wallet: WatchedWallet, priceUSD: Double, change24h: Double) async -> ChainPoll {
        let lamports = (try? await fetchSOLLamports(address: wallet.address)) ?? 0
        let sol = Double(lamports) / 1_000_000_000
        let key = baselineKey(wallet)
        let current = String(lamports)
        var deposits: [DepositEvent] = []
        var alerts: [IslandAlert] = []
        var dirty = false

        if !primedAddresses.contains(key) {
            fundedBaseline[key] = current
            primedAddresses.insert(key)
            dirty = true
        } else {
            let previous = UInt64(fundedBaseline[key] ?? current) ?? lamports
            if lamports > previous {
                let delta = Double(lamports - previous) / 1_000_000_000
                if delta >= 0.001 {
                    let event = DepositEvent(
                        id: "\(key)-\(lamports)-\(Int(Date().timeIntervalSince1970))",
                        walletLabel: wallet.label,
                        address: wallet.address,
                        asset: "SOL",
                        amount: delta,
                        usd: delta * priceUSD,
                        confirmed: true,
                        detectedAt: .now,
                        source: .onchain,
                        statusText: "Confirmed"
                    )
                    deposits.append(event)
                    alerts.append(
                        IslandAlert(
                            id: UUID(),
                            kind: .deposit,
                            title: event.title,
                            detail: "\(wallet.label) +\(event.amountText) (≈ $\(String(format: "%.2f", event.usd)))",
                            createdAt: .now,
                            isRead: false
                        )
                    )
                }
            }
            if fundedBaseline[key] != current {
                fundedBaseline[key] = current
                dirty = true
            }
        }

        return ChainPoll(
            snapshot: WalletSnapshot(
                id: wallet.id,
                label: wallet.label,
                address: wallet.address,
                chain: "SOL",
                balanceNative: sol,
                balanceUSD: sol * priceUSD,
                pnl24hPercent: change24h,
                healthFactor: nil,
                nativeSymbol: "SOL",
                pendingNative: 0
            ),
            deposits: deposits,
            alerts: alerts,
            baselineChanged: dirty
        )
    }

    // MARK: - Network

    private struct AddressStats {
        var chainFunded: Int64
        var chainSpent: Int64
        var memFunded: Int64
        var memSpent: Int64
    }

    private func fetchAddressStats(address: String) async throws -> AddressStats {
        let url = URL(string: "https://mempool.space/api/address/\(address)")!
        let (data, response) = try await session.data(from: url)
        try validate(response)
        let decoded = try JSONDecoder().decode(MempoolAddressResponse.self, from: data)
        return AddressStats(
            chainFunded: decoded.chain_stats.funded_txo_sum,
            chainSpent: decoded.chain_stats.spent_txo_sum,
            memFunded: decoded.mempool_stats.funded_txo_sum,
            memSpent: decoded.mempool_stats.spent_txo_sum
        )
    }

    private func fetchETHBalanceWei(address: String) async throws -> String {
        var addr = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !addr.hasPrefix("0x") { addr = "0x" + addr }
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "eth_getBalance",
            "params": [addr, "latest"]
        ]
        let payload = try JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: URL(string: "https://ethereum.publicnode.com")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = payload
        request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)
        try validate(response)
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let hex = json["result"] as? String
        else { throw URLError(.cannotParseResponse) }
        return hexToDecimalString(hex)
    }

    private func fetchSOLLamports(address: String) async throws -> UInt64 {
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "getBalance",
            "params": [address]
        ]
        let payload = try JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: URL(string: "https://api.mainnet-beta.solana.com")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = payload
        request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)
        try validate(response)
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let result = json["result"] as? [String: Any],
            let value = result["value"] as? NSNumber
        else { throw URLError(.cannotParseResponse) }
        return value.uint64Value
    }

    private func fetchFees() async throws -> Double {
        let url = URL(string: "https://mempool.space/api/v1/fees/recommended")!
        let (data, response) = try await session.data(from: url)
        try validate(response)
        let decoded = try JSONDecoder().decode(MempoolFeesResponse.self, from: data)
        return Double(decoded.halfHourFee)
    }

    private func normalizedAssets(_ assets: [String]) -> [String] {
        RadarWatchlist.sanitize(assets)
    }

    private func fetchMarketTicks(_ assets: [String]) async -> [AssetTick] {
        let assets = normalizedAssets(assets)
        guard !assets.isEmpty else { return [] }

        if let batch = await fetchMarketTicksBatch(assets), !batch.isEmpty {
            return batch
        }

        // One invalid pair (e.g. USDTUSDT) kills the batch — fall back per symbol.
        var ticks: [AssetTick] = []
        for asset in assets {
            if let tick = await fetchMarketTickSingle(asset) {
                ticks.append(tick)
            }
        }
        if !ticks.isEmpty { return ticks }

        if assets.contains("BTC"), let btc = try? await fetchBTCPriceCoinGecko() {
            return [AssetTick(symbol: "BTC", priceUSD: btc.0, change24hPercent: btc.1)]
        }
        return []
    }

    private func fetchMarketTicksBatch(_ assets: [String]) async -> [AssetTick]? {
        let pairs = assets.map { "\($0)USDT" }
        guard
            let json = try? JSONSerialization.data(withJSONObject: pairs),
            let encoded = String(data: json, encoding: .utf8)?
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "https://api.binance.com/api/v3/ticker/24hr?symbols=\(encoded)")
        else {
            return nil
        }

        do {
            let (data, response) = try await session.data(from: url)
            try validate(response)
            let rows = try JSONDecoder().decode([BinanceTicker24h].self, from: data)
            var bySymbol: [String: AssetTick] = [:]
            for row in rows {
                let base = row.symbol.hasSuffix("USDT")
                    ? String(row.symbol.dropLast(4))
                    : row.symbol
                guard let price = Double(row.lastPrice),
                      let change = Double(row.priceChangePercent)
                else { continue }
                bySymbol[base] = AssetTick(symbol: base, priceUSD: price, change24hPercent: change)
            }
            let ordered = assets.compactMap { bySymbol[$0] }
            return ordered.isEmpty ? nil : ordered
        } catch {
            return nil
        }
    }

    private func fetchMarketTickSingle(_ asset: String) async -> AssetTick? {
        let pair = "\(asset)USDT"
        guard let url = URL(string: "https://api.binance.com/api/v3/ticker/24hr?symbol=\(pair)") else {
            return nil
        }
        do {
            let (data, response) = try await session.data(from: url)
            try validate(response)
            let row = try JSONDecoder().decode(BinanceTicker24h.self, from: data)
            guard let price = Double(row.lastPrice),
                  let change = Double(row.priceChangePercent)
            else { return nil }
            return AssetTick(symbol: asset, priceUSD: price, change24hPercent: change)
        } catch {
            return nil
        }
    }

    private func fetchBTCPriceCoinGecko() async throws -> (Double, Double) {
        let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true")!
        let (data, response) = try await session.data(from: url)
        try validate(response)
        let decoded = try JSONDecoder().decode([String: CoinPrice].self, from: data)
        guard let btc = decoded["bitcoin"] else {
            throw URLError(.cannotParseResponse)
        }
        return (btc.usd, btc.usd_24h_change ?? 0)
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - Baseline persistence

    private func loadBaselinesIfNeeded() {
        guard !baselinesLoaded else { return }
        baselinesLoaded = true
        let stored = OnChainBaselineStore.load()
        for (key, record) in stored {
            fundedBaseline[key] = record.amount
            primedAddresses.insert(key)
        }
    }

    private func persistBaselines() {
        var map: [String: OnChainBaselineStore.Record] = [:]
        for (key, amount) in fundedBaseline {
            let unit: String
            if key.hasPrefix("btc:") { unit = "sats" }
            else if key.hasPrefix("eth:") { unit = "wei" }
            else if key.hasPrefix("sol:") { unit = "lamports" }
            else { unit = "native" }
            map[key] = OnChainBaselineStore.Record(amount: amount, unit: unit, updatedAt: .now)
        }
        OnChainBaselineStore.save(map)
    }

    private func baselineKey(_ wallet: WatchedWallet) -> String {
        "\(wallet.chain.rawValue):\(wallet.address.lowercased())"
    }

    // MARK: - Numeric helpers

    private func weiToEther(_ wei: String) -> Double {
        guard let d = Decimal(string: wei) else { return 0 }
        let eth = d / Decimal(string: "1000000000000000000")!
        return NSDecimalNumber(decimal: eth).doubleValue
    }

    private func hexToDecimalString(_ hex: String) -> String {
        var h = hex.lowercased()
        if h.hasPrefix("0x") { h = String(h.dropFirst(2)) }
        if h.isEmpty { return "0" }
        var value = Decimal(0)
        let base = Decimal(16)
        for ch in h {
            guard let digit = Int(String(ch), radix: 16) else { return "0" }
            value = value * base + Decimal(digit)
        }
        return NSDecimalNumber(decimal: value).stringValue
    }

    private func compareNumericString(_ a: String, _ b: String) -> Int {
        let da = Decimal(string: a) ?? 0
        let db = Decimal(string: b) ?? 0
        if da == db { return 0 }
        return da > db ? 1 : -1
    }

    private func subtractNumericString(_ a: String, _ b: String) -> String {
        let da = Decimal(string: a) ?? 0
        let db = Decimal(string: b) ?? 0
        return NSDecimalNumber(decimal: da - db).stringValue
    }

    private func emptySnapshotBase(
        totalBalanceUSD: Double,
        marketChange24h: Double,
        priceUSD: Double,
        feeRate: Double,
        feeLevel: FeeSnapshot.FeeLevel,
        wallets: [WalletSnapshot],
        alerts: [IslandAlert],
        deposits: [DepositEvent],
        status: IslandStatus,
        statusDetail: String?,
        radarLabel: String,
        signals: [MarketSignal],
        ticks: [AssetTick]
    ) -> MarketSnapshot {
        MarketSnapshot(
            totalBalanceUSD: totalBalanceUSD,
            pnl24hPercent: marketChange24h,
            marketChange24hPercent: marketChange24h,
            portfolioPnL24hPercent: nil,
            btcPriceUSD: priceUSD,
            fee: FeeSnapshot(rate: feeRate, unit: "sat/vB", level: feeLevel, updatedAt: .now),
            wallets: wallets,
            alerts: alerts,
            deposits: deposits,
            status: status,
            lastTick: .now,
            dataMode: "radar",
            statusDetail: statusDetail,
            radarLabel: radarLabel,
            binanceBTC: 0,
            binanceBTCUSD: 0,
            binanceConnected: false,
            binanceStatus: "—",
            binanceLiquidHoldings: [],
            earnPositions: [],
            earnOpportunities: [],
            binancePortfolioUSD: 0,
            binanceEarnUSD: 0,
            earnYesterdayRewardsUSD: 0,
            earnStatus: nil,
            fundingStatus: nil,
            activeSignals: signals,
            marketTicks: ticks,
            userStreamLive: false
        )
    }
}

private struct BinanceTicker24h: Decodable {
    let symbol: String
    let lastPrice: String
    let priceChangePercent: String
}

private struct MempoolAddressResponse: Decodable {
    let chain_stats: Stats
    let mempool_stats: Stats

    struct Stats: Decodable {
        let funded_txo_sum: Int64
        let spent_txo_sum: Int64
    }
}

private struct MempoolFeesResponse: Decodable {
    let halfHourFee: Int
}

private struct CoinPrice: Decodable {
    let usd: Double
    let usd_24h_change: Double?
}
