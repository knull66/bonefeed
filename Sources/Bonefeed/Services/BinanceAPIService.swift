import CryptoKit
import Foundation

struct BinanceCredentials: Sendable {
    var apiKey: String
    var apiSecret: String

    var isComplete: Bool {
        !apiKey.isEmpty && !apiSecret.isEmpty
    }
}

struct BinanceSpotBalance: Sendable, Equatable {
    var asset: String
    var free: Double
    var locked: Double
    var wallet: String
    /// Optional valuation from Binance in BTC.
    var btcValuation: Double?

    var total: Double { free + locked }
}

struct BinanceDepositRecord: Identifiable, Sendable, Equatable {
    var id: String
    var coin: String
    var amount: Double
    var network: String
    var status: Int
    var address: String
    var txId: String
    var insertTime: Date

    var statusLabel: String {
        switch status {
        case 0: "Pending"
        case 6: "Credited"
        case 1: "Success"
        default: "Status \(status)"
        }
    }

    var isCompleteEnoughToAlert: Bool {
        status == 0 || status == 1 || status == 6
    }
}

enum BinanceAPIError: LocalizedError {
    case missingCredentials
    case badURL
    case http(Int, String)
    case decoding
    case server(String)

    var errorDescription: String? {
        switch self {
        case .missingCredentials: L10n.t("err.missingCreds")
        case .badURL: L10n.t("err.badURL")
        case .http(let code, let body): "HTTP \(code): \(body.prefix(160))"
        case .decoding: L10n.t("err.decoding")
        case .server(let msg): msg
        }
    }
}

actor BinanceAPIService {
    private let session: URLSession
    private let stablecoins: Set<String> = [
        "USDT", "USDC", "FDUSD", "BUSD", "TUSD", "DAI", "USDP", "USD1"
    ]

    init(session: URLSession = LiveURLSession.shared) {
        self.session = session
    }

    func testConnection(credentials: BinanceCredentials) async throws -> (count: Int, portfolioHint: String) {
        let balances = try await fetchAllBalances(credentials: credentials)
        let assets = balances.map(\.asset).sorted()
        let hint = assets.isEmpty ? "0 assets" : assets.prefix(8).joined(separator: ", ")
        return (balances.count, hint)
    }

    struct BalanceBundle: Sendable {
        var balances: [BinanceSpotBalance]
        var fundingStatus: String?
    }

    /// Spot + Funding (liquid wallets).
    func fetchAllBalances(credentials: BinanceCredentials) async throws -> [BinanceSpotBalance] {
        let bundle = try await fetchBalanceBundle(credentials: credentials)
        return bundle.balances
    }

    func fetchBalanceBundle(credentials: BinanceCredentials) async throws -> BalanceBundle {
        async let spot = fetchSpotBalances(credentials: credentials)
        let fundingResult = await fetchFundingBalancesResult(credentials: credentials)
        let merged = (try await spot) + fundingResult.balances
        return BalanceBundle(
            balances: merged.sorted { $0.total > $1.total },
            fundingStatus: fundingResult.error
        )
    }

    struct EarnBundle: Sendable {
        var positions: [EarnPosition]
        var totalUSD: Double
        var yesterdayRewardsUSD: Double
        var opportunities: [EarnAPROpportunity]
        var status: String?
    }

    func fetchEarnBundle(credentials: BinanceCredentials, prices: [String: Double]) async -> EarnBundle {
        async let flexible = fetchFlexibleEarnResult(credentials: credentials, prices: prices)
        async let locked = fetchLockedEarnResult(credentials: credentials, prices: prices)
        async let account = fetchEarnAccountUSDT(credentials: credentials)

        let flex = await flexible
        let lock = await locked
        let positions = (flex.positions + lock.positions).sorted { $0.usd > $1.usd }
        let accountUSD = await account
        let positionsUSD = positions.reduce(0) { $0 + $1.usd }
        let yesterday = positions.reduce(0) { $0 + ($1.yesterdayRewardsUSD ?? 0) }
        let opportunities = await findBetterAPR(credentials: credentials, positions: positions)

        var errors: [String] = []
        if let e = flex.error { errors.append("Flexible: \(e)") }
        if let e = lock.error { errors.append("Locked: \(e)") }
        // Positions are source of truth. `/simple-earn/account` often lags after redeem
        // and can keep reporting the old total with empty position rows — that made
        // Spot look empty while EARN stayed stuck overnight.
        if positions.isEmpty, let accountUSD, accountUSD > 0.5 {
            errors.append(String(format: L10n.t("status.earnSettling"), accountUSD))
        }
        let status: String? = errors.isEmpty ? nil : errors.joined(separator: " · ")

        return EarnBundle(
            positions: positions,
            totalUSD: positionsUSD,
            yesterdayRewardsUSD: yesterday,
            opportunities: opportunities,
            status: status
        )
    }

    func fetchEarnAccountUSDT(credentials: BinanceCredentials) async -> Double? {
        do {
            let data = try await signedGET(path: "/sapi/v1/simple-earn/account", params: [:], credentials: credentials)
            let row = try JSONDecoder().decode(EarnAccountResponse.self, from: data)
            return Double(row.totalAmountInUSDT ?? "")
        } catch {
            return nil
        }
    }

    private struct EarnFetchResult: Sendable {
        var positions: [EarnPosition]
        var error: String?
    }

    private struct FundingFetchResult: Sendable {
        var balances: [BinanceSpotBalance]
        var error: String?
    }

    private func fetchFlexibleEarnResult(credentials: BinanceCredentials, prices: [String: Double]) async -> EarnFetchResult {
        do {
            let data = try await signedGET(
                path: "/sapi/v1/simple-earn/flexible/position",
                params: ["size": "100", "current": "1"],
                credentials: credentials
            )
            let page = try JSONDecoder().decode(EarnFlexiblePage.self, from: data)
            let positions = (page.rows ?? []).compactMap { row -> EarnPosition? in
                guard let amount = Double(row.totalAmount ?? ""), amount > 0 else { return nil }
                let asset = row.asset ?? "?"
                let px = usdPrice(for: asset, prices: prices)
                let apr = Double(row.latestAnnualPercentageRate ?? "").map { $0 * 100 }
                let yRewards = Double(row.yesterdayRealTimeRewards ?? "")
                let cumulative = Double(row.cumulativeTotalRewards ?? "")
                return EarnPosition(
                    id: "flex-\(row.productId ?? asset)-\(amount)",
                    kind: .flexible,
                    asset: asset,
                    amount: amount,
                    usd: amount * px,
                    aprPercent: apr,
                    productId: row.productId,
                    yesterdayRewards: yRewards,
                    yesterdayRewardsUSD: yRewards.map { $0 * px },
                    cumulativeRewards: cumulative,
                    unlockDate: nil
                )
            }
            return EarnFetchResult(positions: positions, error: nil)
        } catch {
            return EarnFetchResult(positions: [], error: shortError(error))
        }
    }

    private func fetchLockedEarnResult(credentials: BinanceCredentials, prices: [String: Double]) async -> EarnFetchResult {
        do {
            let data = try await signedGET(
                path: "/sapi/v1/simple-earn/locked/position",
                params: ["size": "100", "current": "1"],
                credentials: credentials
            )
            let page = try JSONDecoder().decode(EarnLockedPage.self, from: data)
            let positions = (page.rows ?? []).compactMap { row -> EarnPosition? in
                let amount = Double(row.amount ?? row.totalAmount ?? "") ?? 0
                guard amount > 0 else { return nil }
                let asset = row.asset ?? "?"
                let px = usdPrice(for: asset, prices: prices)
                let apr = Double(row.APY ?? row.apr ?? row.latestAnnualPercentageRate ?? "").map { value in
                    value > 1 ? value : value * 100
                }
                let unlock = parseEarnDate(
                    row.redeemDate?.value ?? row.deliveryDate?.value ?? row.endDate?.value
                )
                let pid = row.positionId?.value ?? row.projectId ?? row.productId ?? asset
                return EarnPosition(
                    id: "locked-\(pid)",
                    kind: .locked,
                    asset: asset,
                    amount: amount,
                    usd: amount * px,
                    aprPercent: apr,
                    productId: pid,
                    yesterdayRewards: Double(row.rewardAmt ?? ""),
                    yesterdayRewardsUSD: Double(row.rewardAmt ?? "").map { $0 * px },
                    cumulativeRewards: Double(row.cumulativeRewardAmt ?? ""),
                    unlockDate: unlock
                )
            }
            return EarnFetchResult(positions: positions, error: nil)
        } catch {
            return EarnFetchResult(positions: [], error: shortError(error))
        }
    }

    private func shortError(_ error: Error) -> String {
        let text = error.localizedDescription
        return text.count > 90 ? String(text.prefix(90)) + "…" : text
    }

    /// Compare current flexible positions vs best listed product APR.
    private func findBetterAPR(credentials: BinanceCredentials, positions: [EarnPosition]) async -> [EarnAPROpportunity] {
        let flex = positions.filter { $0.kind == .flexible }
        guard !flex.isEmpty else { return [] }

        var opportunities: [EarnAPROpportunity] = []
        var seen = Set<String>()
        for pos in flex {
            let asset = pos.asset.uppercased()
            guard seen.insert(asset).inserted else { continue }
            guard let current = pos.aprPercent else { continue }
            guard let best = await bestFlexibleAPR(credentials: credentials, asset: asset) else { continue }
            // Only surface meaningful upgrades (≥ 0.30 percentage points).
            guard best.apr - current >= 0.30 else { continue }
            opportunities.append(
                EarnAPROpportunity(
                    asset: asset,
                    currentAprPercent: current,
                    bestAprPercent: best.apr,
                    bestProductId: best.productId,
                    amountUSD: pos.usd
                )
            )
        }
        return opportunities.sorted { $0.gainPercent > $1.gainPercent }
    }

    private func bestFlexibleAPR(credentials: BinanceCredentials, asset: String) async -> (apr: Double, productId: String?)? {
        do {
            let data = try await signedGET(
                path: "/sapi/v1/simple-earn/flexible/list",
                params: ["asset": asset, "size": "50", "current": "1"],
                credentials: credentials
            )
            let page = try JSONDecoder().decode(EarnProductListPage.self, from: data)
            let best = (page.rows ?? []).compactMap { row -> (Double, String?)? in
                guard let rate = Double(row.latestAnnualPercentageRate ?? "") else { return nil }
                return (rate * 100, row.productId)
            }.max(by: { $0.0 < $1.0 })
            return best.map { (apr: $0.0, productId: $0.1) }
        } catch {
            return nil
        }
    }

    private func parseEarnDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        if let ms = Double(raw), ms > 1_000_000_000_000 {
            return Date(timeIntervalSince1970: ms / 1000)
        }
        if let sec = Double(raw), sec > 1_000_000_000 {
            return Date(timeIntervalSince1970: sec)
        }
        let iso = ISO8601DateFormatter()
        return iso.date(from: raw)
    }

    func fetchSpotBalances(credentials: BinanceCredentials) async throws -> [BinanceSpotBalance] {
        // Merge getUserAsset + classic account — after Earn→Spot redeem, one endpoint
        // can lag while the other already shows the balance.
        var byAsset: [String: BinanceSpotBalance] = [:]

        do {
            let data = try await signedPOST(
                path: "/sapi/v3/asset/getUserAsset",
                params: ["needBtcValuation": "true"],
                credentials: credentials
            )
            let rows = try JSONDecoder().decode([UserAssetRow].self, from: data)
            for row in rows {
                guard let free = Double(row.free), let locked = Double(row.locked) else { continue }
                let total = free + locked
                guard total > 0 else { continue }
                byAsset[row.asset.uppercased()] = BinanceSpotBalance(
                    asset: row.asset,
                    free: free,
                    locked: locked,
                    wallet: "Spot",
                    btcValuation: Double(row.btcValuation ?? "")
                )
            }
        } catch {
            // Account endpoint below is enough.
        }

        do {
            let data = try await signedGET(path: "/api/v3/account", params: [:], credentials: credentials)
            let decoded = try JSONDecoder().decode(AccountResponse.self, from: data)
            for row in decoded.balances {
                guard let free = Double(row.free), let locked = Double(row.locked) else { continue }
                guard free > 0 || locked > 0 else { continue }
                let key = row.asset.uppercased()
                if let existing = byAsset[key] {
                    // Keep the larger total if endpoints disagree mid-redeem.
                    if free + locked > existing.total {
                        byAsset[key] = BinanceSpotBalance(
                            asset: row.asset,
                            free: free,
                            locked: locked,
                            wallet: "Spot",
                            btcValuation: existing.btcValuation
                        )
                    }
                } else {
                    byAsset[key] = BinanceSpotBalance(
                        asset: row.asset,
                        free: free,
                        locked: locked,
                        wallet: "Spot",
                        btcValuation: nil
                    )
                }
            }
        } catch {
            if byAsset.isEmpty { throw error }
        }

        return byAsset.values.sorted { $0.total > $1.total }
    }

    func fetchFundingBalances(credentials: BinanceCredentials) async throws -> [BinanceSpotBalance] {
        let result = await fetchFundingBalancesResult(credentials: credentials)
        return result.balances
    }

    private func fetchFundingBalancesResult(credentials: BinanceCredentials) async -> FundingFetchResult {
        do {
            let data = try await signedPOST(path: "/sapi/v1/asset/get-funding-asset", params: [:], credentials: credentials)
            let rows = try JSONDecoder().decode([FundingAssetRow].self, from: data)
            let balances = rows.compactMap { row -> BinanceSpotBalance? in
                let free = Double(row.free ?? "0") ?? 0
                let locked = Double(row.locked ?? "0") ?? 0
                let freeze = Double(row.freeze ?? "0") ?? 0
                let total = free + locked + freeze
                guard total > 0 else { return nil }
                return BinanceSpotBalance(
                    asset: row.asset,
                    free: free,
                    locked: locked + freeze,
                    wallet: "Funding",
                    btcValuation: Double(row.btcValuation ?? "")
                )
            }
            return FundingFetchResult(balances: balances, error: nil)
        } catch {
            return FundingFetchResult(balances: [], error: "Funding: \(shortError(error))")
        }
    }

    func fetchDepositHistory(credentials: BinanceCredentials, coin: String? = nil, limit: Int = 50) async throws -> [BinanceDepositRecord] {
        var params: [String: String] = [
            "limit": String(limit)
        ]
        if let coin, !coin.isEmpty {
            params["coin"] = coin
        }
        let data = try await signedGET(
            path: "/sapi/v1/capital/deposit/hisrec",
            params: params,
            credentials: credentials
        )
        let rows = try JSONDecoder().decode([DepositResponse].self, from: data)
        return rows.map { row in
            BinanceDepositRecord(
                id: row.id ?? row.txId ?? "\(row.insertTime)-\(row.amount)-\(row.coin)",
                coin: row.coin,
                amount: Double(row.amount) ?? 0,
                network: row.network ?? "",
                status: row.status,
                address: row.address ?? "",
                txId: row.txId ?? "",
                insertTime: Date(timeIntervalSince1970: Double(row.insertTime) / 1000)
            )
        }
    }

    func fetchUSDPrices() async throws -> [String: Double] {
        var request = URLRequest(url: URL(string: "https://api.binance.com/api/v3/ticker/price")!)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw BinanceAPIError.http(-1, "price ticker failed")
        }
        let rows = try JSONDecoder().decode([TickerPrice].self, from: data)
        var prices: [String: Double] = [:]
        for coin in stablecoins {
            prices[coin] = 1
        }
        for row in rows {
            guard row.symbol.hasSuffix("USDT"),
                  let px = Double(row.price) else { continue }
            let asset = String(row.symbol.dropLast(4))
            prices[asset] = px
        }
        return prices
    }

    func valuedHoldings(balances: [BinanceSpotBalance], prices: [String: Double]) -> [BinanceAssetHolding] {
        let btcUSD = prices["BTC"] ?? 0
        return balances.map { bal in
            let px = usdPrice(for: bal.asset, prices: prices)
            var usd = bal.total * px
            if usd <= 0, let btcVal = bal.btcValuation, btcVal > 0, btcUSD > 0 {
                usd = btcVal * btcUSD
            }
            return BinanceAssetHolding(
                asset: bal.asset,
                amount: bal.total,
                usd: usd,
                wallet: bal.wallet
            )
        }
        .sorted {
            if $0.usd == $1.usd { return $0.amount > $1.amount }
            return $0.usd > $1.usd
        }
    }

    private func usdPrice(for asset: String, prices: [String: Double]) -> Double {
        let upper = asset.uppercased()
        if let direct = prices[upper] { return direct }
        if stablecoins.contains(upper) { return 1 }

        // Simple Earn flexible: LDUSDT, LDETH, etc.
        if upper.hasPrefix("LD"), upper.count > 2 {
            let underlying = String(upper.dropFirst(2))
            if let px = prices[underlying] { return px }
            if stablecoins.contains(underlying) { return 1 }
        }

        // Sometimes prefixed earn/vault tokens.
        for prefix in ["LD", "B", "C"] {
            if upper.hasPrefix(prefix), upper.count > prefix.count {
                let underlying = String(upper.dropFirst(prefix.count))
                if let px = prices[underlying] { return px }
            }
        }
        return 0
    }

    private func signedGET(path: String, params: [String: String], credentials: BinanceCredentials) async throws -> Data {
        try await signedRequest(method: "GET", path: path, params: params, credentials: credentials)
    }

    private func signedPOST(path: String, params: [String: String], credentials: BinanceCredentials) async throws -> Data {
        try await signedRequest(method: "POST", path: path, params: params, credentials: credentials)
    }

    private func signedRequest(method: String, path: String, params: [String: String], credentials: BinanceCredentials) async throws -> Data {
        guard credentials.isComplete else { throw BinanceAPIError.missingCredentials }

        var params = params
        params["timestamp"] = String(Int(Date().timeIntervalSince1970 * 1000))
        params["recvWindow"] = "10000"

        let query = params
            .map { key, value in
                let k = key.addingPercentEncoding(withAllowedCharacters: .binanceQueryAllowed) ?? key
                let v = value.addingPercentEncoding(withAllowedCharacters: .binanceQueryAllowed) ?? value
                return "\(k)=\(v)"
            }
            .sorted()
            .joined(separator: "&")

        let signature = hmacSHA256(message: query, secret: credentials.apiSecret)
        let signedQuery = query + "&signature=" + signature

        var request: URLRequest
        if method == "GET" {
            guard let url = URL(string: "https://api.binance.com" + path + "?" + signedQuery) else {
                throw BinanceAPIError.badURL
            }
            request = URLRequest(url: url)
            request.httpMethod = "GET"
        } else {
            guard let url = URL(string: "https://api.binance.com" + path) else {
                throw BinanceAPIError.badURL
            }
            request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data(signedQuery.utf8)
        }
        request.setValue(credentials.apiKey, forHTTPHeaderField: "X-MBX-APIKEY")
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BinanceAPIError.http(-1, "") }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            if let err = try? JSONDecoder().decode(BinanceErrorBody.self, from: data) {
                throw BinanceAPIError.server("\(err.msg) (\(err.code))")
            }
            throw BinanceAPIError.http(http.statusCode, body)
        }
        return data
    }

    private func hmacSHA256(message: String, secret: String) -> String {
        let key = SymmetricKey(data: Data(secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
        return mac.map { String(format: "%02x", $0) }.joined()
    }
}

private extension CharacterSet {
    static var binanceQueryAllowed: CharacterSet {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-_.~")
        return set
    }
}

private struct AccountResponse: Decodable {
    let balances: [BalanceRow]
    struct BalanceRow: Decodable {
        let asset: String
        let free: String
        let locked: String
    }
}

private struct UserAssetRow: Decodable {
    let asset: String
    let free: String
    let locked: String
    let btcValuation: String?
}

private struct FundingAssetRow: Decodable {
    let asset: String
    let free: String?
    let locked: String?
    let freeze: String?
    let btcValuation: String?
}

private struct DepositResponse: Decodable {
    let id: String?
    let amount: String
    let coin: String
    let network: String?
    let status: Int
    let address: String?
    let txId: String?
    let insertTime: Int64
}

private struct BinanceErrorBody: Decodable {
    let code: Int
    let msg: String
}

private struct TickerPrice: Decodable {
    let symbol: String
    let price: String
}

private struct EarnAccountResponse: Decodable {
    let totalAmountInUSDT: String?
    let totalFlexibleAmountInUSDT: String?
    let totalLockedInUSDT: String?
}

private struct EarnFlexiblePage: Decodable {
    let rows: [EarnFlexibleRow]?
    let total: Int?
}

private struct EarnFlexibleRow: Decodable {
    let asset: String?
    let productId: String?
    let totalAmount: String?
    let latestAnnualPercentageRate: String?
    let yesterdayRealTimeRewards: String?
    let cumulativeTotalRewards: String?
}

private struct EarnLockedPage: Decodable {
    let rows: [EarnLockedRow]?
    let total: Int?
}

private struct EarnLockedRow: Decodable {
    let asset: String?
    let amount: String?
    let totalAmount: String?
    let APY: String?
    let apr: String?
    let latestAnnualPercentageRate: String?
    let positionId: LosslessString?
    let projectId: String?
    let productId: String?
    let redeemDate: LosslessString?
    let deliveryDate: LosslessString?
    let endDate: LosslessString?
    let rewardAmt: String?
    let cumulativeRewardAmt: String?
}

private struct EarnProductListPage: Decodable {
    let rows: [EarnProductRow]?
}

private struct EarnProductRow: Decodable {
    let productId: String?
    let latestAnnualPercentageRate: String?
}

/// Decodes JSON string or number into String.
private struct LosslessString: Decodable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            value = s
        } else if let i = try? container.decode(Int64.self) {
            value = String(i)
        } else if let d = try? container.decode(Double.self) {
            value = String(d)
        } else {
            value = ""
        }
    }
}
