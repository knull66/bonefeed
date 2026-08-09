import AppKit
import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class AppStore {
    var snapshot: MarketSnapshot
    var thresholds: AlertThresholds
    var watchedWallets: [WatchedWallet]
    var draftAddress: String = ""
    var draftLabel: String = "Wallet"
    var draftChain: ChainKind = .btc
    var isPaused = false
    var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: Keys.soundEnabled) }
    }
    var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }
    var appTheme: AppTheme {
        didSet { UserDefaults.standard.set(appTheme.rawValue, forKey: Keys.appTheme) }
    }

    func selectTheme(_ theme: AppTheme) {
        guard ProStore.isThemeAllowed(theme, isPro: isPro) else {
            proMessage = t("pro.gate.theme")
            return
        }
        appTheme = theme
    }
    var appLanguage: AppLanguage = .english {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: Keys.appLanguage)
            L10n.language = appLanguage
            // Refresh status strings that depend on language.
            launchAtLoginStatusText = LaunchAtLogin.statusText
            Task { await refreshNotificationStatus() }
        }
    }
    var palette: ThemePalette { ThemePalette.forTheme(appTheme) }

    /// Local mirror of StoreKit entitlement for SwiftUI + gating.
    var isProUnlocked: Bool = false

    var isPro: Bool { isProUnlocked }

    let proStore = ProStore.shared

    func t(_ key: String) -> String { L10n.t(key, lang: appLanguage) }

    func syncProStatus() {
        let wasPro = isProUnlocked
        isProUnlocked = proStore.isPro
        if !isProUnlocked {
            if !ProStore.isThemeAllowed(appTheme, isPro: false) {
                appTheme = .cyberDark
            }
            if !wasPro && watchedAssets.count > ProLimits.freeWatchlistCap {
                // Keep existing over-cap list until they edit; only trim when leaving Pro.
            }
            if wasPro && watchedAssets.count > ProLimits.freeWatchlistCap {
                watchedAssets = Array(watchedAssets.prefix(ProLimits.freeWatchlistCap))
                persistWatchedAssets()
            }
        }
    }

    func purchasePro() async {
        proMessage = t("pro.purchasing")
        let ok = await proStore.purchase()
        syncProStatus()
        proMessage = ok ? t("pro.unlocked") : (proStore.lastError ?? t("pro.purchaseFailed"))
        if ok { await refresh(force: true) }
    }

    func restorePro() async {
        proMessage = t("pro.restoring")
        let ok = await proStore.restore()
        syncProStatus()
        proMessage = ok ? t("pro.restored") : (proStore.lastError ?? t("pro.restoreFailed"))
        if ok { await refresh(force: true) }
    }

    func unlockProLocal() {
        proStore.unlockLocal()
        syncProStatus()
        proMessage = t("pro.unlockedDebug")
        Task { await refresh(force: true) }
    }

    func lockProLocal() {
        proStore.lockLocal()
        syncProStatus()
        proMessage = t("pro.locked")
        Task { await refresh(force: true) }
    }

    func openProSettings() {
        openAppSettings()
    }

    var proMessage: String = ""

    var proBuyLabel: String {
        if let price = proStore.priceText {
            return "\(t("pro.buy")) — \(price)"
        }
        return t("pro.buy")
    }

    /// When true, next panel open skips boot splash (e.g. reopen guide).
    var skipNextSplash = false

    func showGuideFromSettings() {
        showOnboarding = true
        skipNextSplash = true
        SettingsWindowController.shared.close()
        if isPanelOpen {
            // Refresh content without replaying splash over the guide.
            panelOpenToken &+= 1
        } else {
            togglePanel()
        }
    }
    var launchAtLoginEnabled: Bool = false
    var notificationStatusText: String = "…"
    var launchAtLoginStatusText: String = LaunchAtLogin.statusText
    var selectedTab: PanelTab = .radar {
        didSet {
            if selectedTab == .log {
                markAlertsRead()
            }
        }
    }
    /// Submenu inside RADAR: OVERVIEW | P2P
    var selectedRadarSubTab: RadarSubTab = .overview
    var isRefreshing = false
    var depositLog: [DepositEvent] = []
    var watchedAssets: [String] = RadarWatchlist.default
    /// First-run tutorial overlay on the panel.
    var showOnboarding: Bool
    // Binance credentials draft (not persisted until Save)
    var binanceAPIKeyDraft: String = ""
    var binanceAPISecretDraft: String = ""
    var binanceHasCredentials = false
    var binanceMessage: String = L10n.t("msg.pasteKey")
    var isTestingBinance = false

    var alertLog: [IslandAlert] = []
    var bannerAlert: IslandAlert?
    var pillPulse = false
    /// True while the notch should stay open for a fresh alert (store-driven).
    var alertNotchExpanded = false
    var lastRefreshAt: Date?

    /// Floating panel UI (driven by IslandUIController).
    var isPanelOpen = false
    var isPanelPinned = false
    /// Bumped each time the panel is shown — drives splash replay.
    var panelOpenToken: UInt = 0
    var onTogglePanel: (() -> Void)?
    var onTogglePin: (() -> Void)?
    var onCollapsePanel: (() -> Void)?
    /// Notch hover peek — resizes the menu-bar panel.
    var onNotchHoverExpand: ((Bool) -> Void)?
    /// Preferred notch chrome mode (collapsed / P2P timer dock / full card).
    var onNotchModeChange: ((NotchDisplayMode) -> Void)?
    var notchHoverExpanded = false
    var notchDisplayMode: NotchDisplayMode = .collapsed
    /// Live menu-bar strip height (pts) — keeps the collapsed island flush with the bar.
    var notchMenuBarHeight: CGFloat = 24
    /// Set by IslandNotchView while the pointer is over the island.
    var notchPointerInside = false
    private var alertNotchTask: Task<Void, Never>?

    private let market = BitcoinMarketService()
    private let binance = BinanceAPIService()
    private let userStream = BinanceUserStreamService()
    private var loopTask: Task<Void, Never>?
    private var knownSignatures = Set<String>()
    private var notifyCooldownUntil: [String: Date] = [:]
    private var seenBinanceDepositIDs: Set<String>
    private var binancePrimed = false
    /// orderNumber → last seen orderStatus
    private var seenP2POrderStatus: [String: String]
    private var p2pPrimed = false
    /// Local demo P2P orders (not from Binance) — for UI testing without a real trade.
    var simulatedP2POrders: [BinanceP2POrder] = []
    private var bannerTask: Task<Void, Never>?
    private var pulseTask: Task<Void, Never>?
    private var cachedCredentials: BinanceCredentials?
    private var lastEarnUSD: Double?
    private var earnBaselineDone = false
    private var isRefreshInFlight = false
    private var refreshAgainQueued = false
    private var portfolioSamples: [PortfolioHistoryStore.Sample] = []
    private var userStreamStarted = false
    private var streamRefreshPending = false

    private enum Keys {
        static let soundEnabled = "bonefeed.soundEnabled"
        static let notificationsEnabled = "bonefeed.notificationsEnabled"
        static let appTheme = "bonefeed.appTheme"
        static let wallets = "bonefeed.wallets"
        static let seenBinance = "bonefeed.seenBinanceDeposits"
        static let seenP2P = "bonefeed.seenP2POrders"
        static let thresholds = "bonefeed.thresholds"
        static let watchedAssets = "bonefeed.watchedAssets"
        static let onboardingDone = "bonefeed.onboardingDone"
        static let appLanguage = "bonefeed.appLanguage"
    }

    enum PanelTab: String, CaseIterable, Identifiable {
        case radar
        case spot
        case earn
        case log

        var id: String { rawValue }

        var title: String {
            switch self {
            case .radar: "RADAR"
            case .spot: "SPOT"
            case .earn: "EARN"
            case .log: "LOG"
            }
        }
    }

    enum RadarSubTab: String, CaseIterable, Identifiable {
        case overview
        case p2p

        var id: String { rawValue }

        var title: String {
            switch self {
            case .overview: "OVERVIEW"
            case .p2p: "P2P"
            }
        }
    }

    func completeOnboarding() {
        showOnboarding = false
        UserDefaults.standard.set(true, forKey: Keys.onboardingDone)
    }

    func openAppSettings() {
        SettingsWindowController.shared.show(store: self)
    }

    func togglePanel() {
        onTogglePanel?()
    }

    func togglePanelPin() {
        onTogglePin?()
    }

    func collapsePanel() {
        onCollapsePanel?()
    }

    /// Open the dashboard on Radar → P2P (live order status).
    func openP2PStatus() {
        selectedTab = .radar
        selectedRadarSubTab = .p2p
        if !isPanelOpen {
            onTogglePanel?()
        }
    }

    /// Keep a slim timer dock while an open P2P order exists.
    func syncNotchMode(hovering: Bool = false) {
        let mode: NotchDisplayMode
        if hovering || alertNotchExpanded {
            mode = .expanded
        } else if snapshot.openP2POrders.first != nil {
            mode = .p2pDock
        } else {
            mode = .collapsed
        }
        onNotchModeChange?(mode)
    }

    init() {
        LegacyBrandMigration.runIfNeeded()
        if UserDefaults.standard.object(forKey: Keys.soundEnabled) == nil {
            soundEnabled = true
        } else {
            soundEnabled = UserDefaults.standard.bool(forKey: Keys.soundEnabled)
        }
        if UserDefaults.standard.object(forKey: Keys.notificationsEnabled) == nil {
            notificationsEnabled = true
        } else {
            notificationsEnabled = UserDefaults.standard.bool(forKey: Keys.notificationsEnabled)
        }
        if let raw = UserDefaults.standard.string(forKey: Keys.appTheme),
           let saved = AppTheme(rawValue: raw) {
            appTheme = saved
        } else {
            appTheme = .cyberDark
        }
        launchAtLoginEnabled = LaunchAtLogin.isEnabled
        launchAtLoginStatusText = LaunchAtLogin.statusText

        if let seen = UserDefaults.standard.array(forKey: Keys.seenBinance) as? [String] {
            seenBinanceDepositIDs = Set(seen)
            binancePrimed = !seen.isEmpty
        } else {
            seenBinanceDepositIDs = []
            binancePrimed = false
        }

        if UserDefaults.standard.object(forKey: Keys.seenP2P) != nil {
            if let data = UserDefaults.standard.data(forKey: Keys.seenP2P),
               let saved = try? JSONDecoder().decode([String: String].self, from: data) {
                seenP2POrderStatus = saved
            } else {
                seenP2POrderStatus = [:]
            }
            p2pPrimed = true
        } else {
            seenP2POrderStatus = [:]
            p2pPrimed = false
        }

        let loadedWallets: [WatchedWallet]
        if let data = UserDefaults.standard.data(forKey: Keys.wallets),
           let saved = try? JSONDecoder().decode([WatchedWallet].self, from: data),
           !saved.isEmpty {
            loadedWallets = saved
        } else {
            loadedWallets = [.binanceSample]
        }
        watchedWallets = loadedWallets

        if let data = UserDefaults.standard.data(forKey: Keys.thresholds),
           let saved = try? JSONDecoder().decode(AlertThresholds.self, from: data) {
            thresholds = saved
        } else {
            thresholds = .default
        }
        if let saved = UserDefaults.standard.array(forKey: Keys.watchedAssets) as? [String], !saved.isEmpty {
            let cleaned = RadarWatchlist.sanitize(saved)
            watchedAssets = cleaned
            if cleaned != saved.map({ $0.uppercased() }) {
                UserDefaults.standard.set(cleaned, forKey: Keys.watchedAssets)
            }
        } else {
            watchedAssets = RadarWatchlist.default
        }
        showOnboarding = !UserDefaults.standard.bool(forKey: Keys.onboardingDone)
        portfolioSamples = PortfolioHistoryStore.load()
        let resolvedLanguage: AppLanguage
        if let raw = UserDefaults.standard.string(forKey: Keys.appLanguage),
           let saved = AppLanguage(rawValue: raw) {
            resolvedLanguage = saved
        } else {
            resolvedLanguage = .english
        }
        L10n.language = resolvedLanguage
        binanceMessage = L10n.t("msg.pasteKey")
        snapshot = MarketSnapshot(
            totalBalanceUSD: 0,
            pnl24hPercent: 0,
            marketChange24hPercent: 0,
            portfolioPnL24hPercent: nil,
            btcPriceUSD: 0,
            fee: FeeSnapshot(rate: 0, unit: "sat/vB", level: .normal, updatedAt: .now),
            wallets: [],
            alerts: [],
            deposits: [],
            status: .idle,
            lastTick: .now,
            dataMode: "starting",
            statusDetail: L10n.t("msg.bootDetail"),
            radarLabel: RadarCode.boot,
            binanceBTC: 0,
            binanceBTCUSD: 0,
            binanceConnected: false,
            binanceStatus: "No API",
            binanceLiquidHoldings: [],
            earnPositions: [],
            earnOpportunities: [],
            binancePortfolioUSD: 0,
            binanceEarnUSD: 0,
            earnYesterdayRewardsUSD: 0,
            earnStatus: nil,
            fundingStatus: nil,
            activeSignals: [],
            marketTicks: [],
            userStreamLive: false,
            p2pOrders: [],
            p2pStatus: nil
        )

        appLanguage = resolvedLanguage
        L10n.language = appLanguage
        launchAtLoginStatusText = LaunchAtLogin.statusText
        reloadCredentialState()
        if UserDefaults.standard.data(forKey: Keys.wallets) == nil {
            persistWallets()
        }
        Task { await refreshNotificationStatus() }
        start()
    }

    func enableNotifications() async {
        notificationsEnabled = true
        await AppNotifier.bootstrap()
        _ = await AppNotifier.requestAuthorization(sendRegistrationPing: true)
        await refreshNotificationStatus()
    }

    func openNotificationSettings() {
        AppNotifier.openSystemNotificationSettings()
    }

    func refreshNotificationStatus() async {
        let status = await AppNotifier.authorizationStatus()
        notificationStatusText = AppNotifier.statusLabel(status)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginStatusText = LaunchAtLogin.setEnabled(enabled)
        launchAtLoginEnabled = LaunchAtLogin.isEnabled
        if SMAppService.mainApp.status == .requiresApproval {
            LaunchAtLogin.openLoginItemsSettings()
        }
    }

    func testNotification() {
        Task {
            if await AppNotifier.authorizationStatus() == .notDetermined {
                _ = await AppNotifier.requestAuthorization()
            }
            await refreshNotificationStatus()
            await AppNotifier.notify(
                title: "Test \(Brand.name)",
                body: t("msg.testNotifyBody"),
                sound: soundEnabled
            )
        }
    }

    func start() {
        proStore.start()
        NotificationCenter.default.addObserver(
            forName: .bonefeedProStatusChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.syncProStatus() }
        }
        Task {
            await proStore.refreshEntitlements()
            await proStore.loadProduct()
            syncProStatus()
        }
        guard loopTask == nil else { return }
        loopTask = Task { [weak self] in
            guard let self else { return }
            await self.refresh()
            while !Task.isCancelled {
                let delay = self.pollIntervalSeconds
                try? await Task.sleep(for: .seconds(delay))
                await self.refresh()
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        Task { await userStream.stop() }
        userStreamStarted = false
    }

    private var pollIntervalSeconds: Double {
        if streamRefreshPending { return 3 }
        switch snapshot.status {
        case .actionNeeded, .alert, .error:
            return 10
        case .watching, .idle:
            if snapshot.activeSignals.contains(where: { $0.kind != .calm }) { return 12 }
            // Keep markets fresh; 30s felt "stuck" next to other tickers.
            return 15
        }
    }

    /// Manual refresh (LIVE / RUN). Ignores pause for one tick.
    func forceRefresh() {
        isPaused = false
        Task { await refresh(force: true) }
    }

    func refresh(force: Bool = false) async {
        if isPaused && !force { return }
        if isRefreshInFlight {
            refreshAgainQueued = true
            return
        }
        isRefreshInFlight = true
        isRefreshing = true
        defer {
            isRefreshInFlight = false
            isRefreshing = false
            lastRefreshAt = .now
            streamRefreshPending = false
            if refreshAgainQueued {
                refreshAgainQueued = false
                Task { await refresh(force: true) }
            }
        }

        let result = await market.fetchRadar(
            wallets: watchedWallets,
            thresholds: thresholds,
            watchAssets: watchedAssets
        )
        var snap = result.snapshot
        var extraAlerts = result.snapshot.alerts
        var newDeposits = result.newDeposits

        if isPro, let credentials = loadCredentials() {
            await ensureUserStream(credentials: credentials)
            do {
                async let balTask = binance.fetchBalanceBundle(credentials: credentials)
                async let depTask = binance.fetchDepositHistory(credentials: credentials, coin: nil, limit: 50)
                async let priceTask = binance.fetchUSDPrices()
                async let p2pTask = fetchP2POrdersIfEnabled(credentials: credentials)
                let bundle = try await balTask
                var balances = bundle.balances
                let deposits = try await depTask
                let prices = try await priceTask
                let earn = await binance.fetchEarnBundle(credentials: credentials, prices: prices)
                let p2pOutcome = await p2pTask

                // LD* ledger tokens mirror flexible Earn — drop only while Earn positions exist.
                // After full redeem, remaining LD* (if any) count as Spot so we don't hide funds.
                if !earn.positions.isEmpty {
                    balances = balances.filter { !$0.asset.uppercased().hasPrefix("LD") }
                }

                let liquid = await binance.valuedHoldings(balances: balances, prices: prices)
                let earnUSD = earn.totalUSD
                let liquidUSD = liquid.reduce(0) { $0 + $1.usd }
                let portfolioUSD = liquidUSD + earnUSD
                let btc = balances.filter { $0.asset.uppercased() == "BTC" }.reduce(0) { $0 + $1.total }

                snap.binanceLiquidHoldings = liquid
                snap.earnPositions = earn.positions
                snap.earnOpportunities = earn.opportunities
                snap.binancePortfolioUSD = portfolioUSD
                snap.binanceEarnUSD = earnUSD
                snap.earnYesterdayRewardsUSD = earn.yesterdayRewardsUSD
                snap.earnStatus = earn.status
                snap.fundingStatus = bundle.fundingStatus
                snap.binanceBTC = btc
                snap.binanceBTCUSD = btc * (prices["BTC"] ?? snap.btcPriceUSD)
                snap.binanceConnected = true
                snap.userStreamLive = userStreamStarted
                snap.binanceStatus = portfolioUSD <= 0 && liquid.isEmpty && earn.positions.isEmpty
                    ? "No Spot/Funding/Earn balance"
                    : "Spot \(liquidUSD.usdCompact) · Earn \(earnUSD.usdCompact)"
                snap.totalBalanceUSD = portfolioUSD
                snap.dataMode = userStreamStarted ? "binance+stream+chain" : "binance+earn+chain"

                PortfolioHistoryStore.record(usd: portfolioUSD, into: &portfolioSamples)
                if let portPnL = PortfolioHistoryStore.change24hPercent(currentUSD: portfolioUSD, samples: portfolioSamples) {
                    snap.portfolioPnL24hPercent = portPnL
                    snap.pnl24hPercent = portPnL
                } else {
                    snap.portfolioPnL24hPercent = nil
                    snap.pnl24hPercent = snap.marketChange24hPercent
                }

                if let earnErr = earn.status {
                    snap.statusDetail = earnErr
                } else if let fundErr = bundle.fundingStatus {
                    snap.statusDetail = fundErr
                } else if liquid.isEmpty && earn.positions.isEmpty {
                    snap.statusDetail = "API OK. No liquid / Earn balance."
                } else if earn.yesterdayRewardsUSD > 0 {
                    snap.statusDetail = "Rewards yday \(earn.yesterdayRewardsUSD.usdCompact) · Earn \(earnUSD.usdCompact)"
                } else if earnUSD > 0 {
                    snap.statusDetail = "Earn live · \(earn.positions.count) positions"
                } else {
                    snap.statusDetail = "Spot/Funding \(liquid.count) assets"
                }

                let fresh = processBinanceDeposits(deposits, prices: prices)
                newDeposits.append(contentsOf: fresh)
                for event in fresh {
                    extraAlerts.append(
                        IslandAlert(
                            id: UUID(),
                            kind: .deposit,
                            title: event.title,
                            detail: "\(event.amountText) · ≈ \(event.usd.usdCompact) · \(event.statusText)",
                            createdAt: .now,
                            isRead: false
                        )
                    )
                }

                if let earnChange = processEarnDelta(currentEarnUSD: earnUSD) {
                    extraAlerts.append(earnChange.alert)
                    newDeposits.append(
                        DepositEvent(
                            id: "earn-\(Int(Date().timeIntervalSince1970))",
                            walletLabel: "Binance Earn",
                            address: "",
                            asset: "USD",
                            amount: abs(earnChange.deltaUSD),
                            usd: abs(earnChange.deltaUSD),
                            confirmed: true,
                            detectedAt: .now,
                            source: .binance,
                            statusText: earnChange.deltaUSD >= 0 ? "Earn +" : "Earn −"
                        )
                    )
                }

                for position in earn.positions where position.kind == .locked {
                    if let days = position.daysRemaining, days >= 0, days <= 3 {
                        extraAlerts.append(
                            IslandAlert(
                                id: UUID(),
                                kind: .earn,
                                title: t("msg.unlockSoon"),
                                detail: "\(position.asset) · \(position.unlockText ?? "") · \(position.usd.usdCompact)",
                                createdAt: .now,
                                isRead: false
                            )
                        )
                    }
                }

                switch p2pOutcome {
                case .success(let orders):
                    let fiatFilter = thresholds.p2pFiat.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    let visible = orders.filter { order in
                        fiatFilter.isEmpty || order.fiat == fiatFilter
                    }
                    let open = visible.filter(\.isOpen).sorted { $0.createTime > $1.createTime }
                    let recentClosed = visible.filter { !$0.isOpen }.sorted { $0.createTime > $1.createTime }
                    snap.p2pOrders = mergedP2PDisplayOrders(apiOpen: open, apiClosed: recentClosed)
                    let openCount = snap.openP2POrders.count
                    snap.p2pStatus = openCount == 0
                        ? (visible.isEmpty && simulatedP2POrders.isEmpty ? "No recent P2P orders" : "No open orders")
                        : "\(openCount) open"
                    extraAlerts.append(contentsOf: processP2POrders(orders))
                case .failure(let message):
                    snap.p2pOrders = mergedP2PDisplayOrders(apiOpen: [], apiClosed: [])
                    snap.p2pStatus = simulatedP2POrders.isEmpty ? message : "\(snap.openP2POrders.count) open · demo"
                    // Soft-fail: Spot/Earn keep working if C2C permission is missing.
                    if thresholds.p2pAlertsEnabled, snap.statusDetail == nil, simulatedP2POrders.isEmpty {
                        snap.statusDetail = "P2P: \(message)"
                    }
                case .skipped:
                    snap.p2pOrders = mergedP2PDisplayOrders(apiOpen: [], apiClosed: [])
                    snap.p2pStatus = simulatedP2POrders.isEmpty ? nil : "\(snap.openP2POrders.count) open · demo"
                }

                let hasUnlockSoon = extraAlerts.contains {
                    $0.kind == .earn && $0.title.hasPrefix("Unlock")
                }
                let hasHealth = extraAlerts.contains { $0.kind == .health }
                let hasP2P = extraAlerts.contains { $0.kind == .p2p }
                if !fresh.isEmpty {
                    snap.status = .actionNeeded
                    snap.radarLabel = RadarCode.deposit
                } else if hasP2P {
                    snap.status = .actionNeeded
                    snap.radarLabel = RadarCode.p2p
                    selectedTab = .radar
                    selectedRadarSubTab = .p2p
                } else if hasHealth {
                    snap.radarLabel = RadarCode.health
                    if snap.status == .watching || snap.status == .idle {
                        snap.status = .alert
                    }
                } else if hasUnlockSoon {
                    snap.radarLabel = RadarCode.unlock
                    if snap.status == .watching || snap.status == .idle {
                        snap.status = .alert
                    }
                } else if snap.activeSignals.contains(where: { $0.kind == .dump || $0.kind == .pump }) {
                    snap.radarLabel = RadarCode.signal
                } else if RadarCode.calmCodes.contains(snap.radarLabel)
                    || [RadarCode.unlock, RadarCode.signal, RadarCode.health, RadarCode.p2p, "LISTENING", "UNLOCK", "SIGNAL", "HEALTH", "P2P"].contains(snap.radarLabel) {
                    snap.radarLabel = earnUSD > 0 ? RadarCode.earn : RadarCode.connected
                }
            } catch {
                snap.binanceConnected = false
                snap.binanceStatus = error.localizedDescription
                binanceMessage = error.localizedDescription
            }
        } else {
            snap.binanceConnected = false
            snap.binanceStatus = t("msg.noApi")
            snap.userStreamLive = false
            if snap.statusDetail == nil {
                snap.statusDetail = t("msg.noApiDetail")
            }
        }

        snap.activeSignals.sort { lhs, rhs in
            signalPriority(lhs.kind) < signalPriority(rhs.kind)
        }

        snap.alerts = extraAlerts
        apply(snapshot: snap, newDeposits: newDeposits)
        syncNotchMode(hovering: notchPointerInside)
    }

    private func ensureUserStream(credentials: BinanceCredentials) async {
        guard !userStreamStarted else { return }
        userStreamStarted = true
        await userStream.start(credentials: credentials) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.streamRefreshPending = true
                await self.refresh(force: true)
            }
        }
    }

    private func signalPriority(_ kind: MarketSignal.Kind) -> Int {
        switch kind {
        case .health: 0
        case .dump: 1
        case .pump: 2
        case .feeHigh: 3
        case .calm: 4
        }
    }

    func togglePause() {
        isPaused.toggle()
        if !isPaused {
            Task { await refresh(force: true) }
        }
    }

    func markAlertsRead() {
        for i in alertLog.indices {
            alertLog[i].isRead = true
        }
        for i in snapshot.alerts.indices {
            snapshot.alerts[i].isRead = true
        }
    }

    func dismissAlerts() {
        alertLog = []
        depositLog = []
        snapshot.alerts = []
        bannerAlert = nil
        knownSignatures.removeAll()
        notifyCooldownUntil.removeAll()
        if snapshot.status != .idle && snapshot.status != .error {
            snapshot.status = .watching
            snapshot.radarLabel = binanceHasCredentials ? RadarCode.connected : RadarCode.ok
        }
    }

    func resetThresholds() {
        updateThresholds(.default)
    }

    func updateFeeHigh(_ value: Double) {
        var next = thresholds
        next.feeHigh = value
        updateThresholds(next)
    }

    func updatePnLDrop(_ value: Double) {
        var next = thresholds
        next.pnlDropPercent = value
        updateThresholds(next)
    }

    func updatePnLPump(_ value: Double) {
        var next = thresholds
        next.pnlPumpPercent = value
        updateThresholds(next)
    }

    func updateCooldownMinutes(_ value: Int) {
        var next = thresholds
        next.cooldownMinutes = max(5, min(180, value))
        updateThresholds(next)
    }

    func updateQuietHours(enabled: Bool? = nil, start: Int? = nil, end: Int? = nil) {
        var next = thresholds
        if let enabled { next.quietHoursEnabled = enabled }
        if let start { next.quietHoursStart = max(0, min(23, start)) }
        if let end { next.quietHoursEnd = max(0, min(23, end)) }
        updateThresholds(next)
    }

    func updateHealthFactorWarn(_ value: Double) {
        var next = thresholds
        next.healthFactorWarn = value
        updateThresholds(next)
    }

    func setHealthAlertsEnabled(_ enabled: Bool) {
        var next = thresholds
        next.healthAlertsEnabled = enabled
        updateThresholds(next)
    }

    func setP2PAlertsEnabled(_ enabled: Bool) {
        guard isPro else { return }
        var next = thresholds
        next.p2pAlertsEnabled = enabled
        updateThresholds(next)
    }

    func setP2PFiat(_ fiat: String) {
        guard isPro else { return }
        var next = thresholds
        next.p2pFiat = fiat.uppercased()
        if next.p2pFiat == "AUTO" { next.p2pFiat = "" }
        updateThresholds(next)
    }

    func toggleSignalAsset(_ symbol: String) {
        let s = symbol.uppercased()
        var next = thresholds
        if next.signalAssets.isEmpty {
            // Start filter with all watchlist assets except the one turned off.
            next.signalAssets = watchedAssets.filter { $0 != s }
        } else if let idx = next.signalAssets.firstIndex(of: s) {
            next.signalAssets.remove(at: idx)
        } else {
            next.signalAssets.append(s)
        }
        if Set(next.signalAssets) == Set(watchedAssets) || next.signalAssets.isEmpty {
            next.signalAssets = []
        }
        updateThresholds(next)
    }

    func setFeeAlertsEnabled(_ enabled: Bool) {
        var next = thresholds
        next.feeAlertsEnabled = enabled
        thresholds = next
        persistThresholds()
        knownSignatures.removeAll()
        Task { await refresh() }
    }

    func setPnLAlertsEnabled(_ enabled: Bool) {
        var next = thresholds
        next.pnlAlertsEnabled = enabled
        thresholds = next
        persistThresholds()
        knownSignatures.removeAll()
        Task { await refresh() }
    }

    func updateThresholds(_ next: AlertThresholds) {
        thresholds = next
        persistThresholds()
        knownSignatures.removeAll()
        Task { await refresh() }
    }

    func openLoginItemsSettings() {
        LaunchAtLogin.openLoginItemsSettings()
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = LaunchAtLogin.isEnabled
        launchAtLoginStatusText = LaunchAtLogin.statusText
    }

    func saveBinanceCredentials() {
        guard isPro else {
            binanceMessage = t("pro.gate.binance")
            return
        }
        let key = binanceAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = binanceAPISecretDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !secret.isEmpty else {
            binanceMessage = t("msg.keyRequired")
            return
        }
        do {
            try LocalCredentialStore.save(apiKey: key, apiSecret: secret)
            KeychainStore.clearBinanceCredentials()
            cachedCredentials = BinanceCredentials(apiKey: key, apiSecret: secret)
            binanceAPISecretDraft = ""
            binanceHasCredentials = true
            binanceMessage = t("msg.savedEncrypted")
            userStreamStarted = false
            Task {
                await userStream.stop()
                await testBinanceConnection()
            }
        } catch {
            cachedCredentials = BinanceCredentials(apiKey: key, apiSecret: secret)
            binanceHasCredentials = true
            binanceMessage = "\(t("msg.saveFailed")) \(error.localizedDescription)"
            Task { await testBinanceConnection() }
        }
    }

    func clearBinanceCredentials() {
        LocalCredentialStore.clear()
        KeychainStore.clearBinanceCredentials()
        cachedCredentials = nil
        binanceAPIKeyDraft = ""
        binanceAPISecretDraft = ""
        binanceHasCredentials = false
        binancePrimed = false
        seenBinanceDepositIDs = []
        UserDefaults.standard.removeObject(forKey: Keys.seenBinance)
        p2pPrimed = false
        seenP2POrderStatus = [:]
        UserDefaults.standard.removeObject(forKey: Keys.seenP2P)
        snapshot.binanceConnected = false
        snapshot.binanceBTC = 0
        snapshot.binanceBTCUSD = 0
        snapshot.binanceStatus = "No API"
        snapshot.binanceLiquidHoldings = []
        snapshot.earnPositions = []
        snapshot.earnOpportunities = []
        snapshot.binancePortfolioUSD = 0
        snapshot.binanceEarnUSD = 0
        snapshot.earnYesterdayRewardsUSD = 0
        snapshot.earnStatus = nil
        snapshot.fundingStatus = nil
        snapshot.userStreamLive = false
        snapshot.p2pOrders = []
        snapshot.p2pStatus = nil
        lastEarnUSD = nil
        earnBaselineDone = false
        userStreamStarted = false
        Task { await userStream.stop() }
        binanceMessage = t("msg.cleared")
    }

    func testBinanceConnection() async {
        guard isPro else {
            binanceMessage = t("pro.gate.binance")
            return
        }
        guard let credentials = loadCredentials() else {
            binanceMessage = t("msg.saveFirst")
            return
        }
        isTestingBinance = true
        do {
            let result = try await binance.testConnection(credentials: credentials)
            binanceMessage = "OK · \(result.count) assets (\(result.portfolioHint))"
            binanceHasCredentials = true
            await refresh()
        } catch {
            binanceMessage = error.localizedDescription
            binanceHasCredentials = loadCredentials() != nil
        }
        isTestingBinance = false
    }

    func toggleWatchedAsset(_ symbol: String) {
        let s = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !s.isEmpty else { return }
        if RadarWatchlist.nonTickerBases.contains(s) { return }

        var next = watchedAssets
        if let idx = next.firstIndex(of: s) {
            guard next.count > 1 else { return }
            next.remove(at: idx)
        } else {
            guard isPro || next.count < ProLimits.freeWatchlistCap else {
                proMessage = t("pro.gate.watchlist")
                return
            }
            next.append(s)
        }
        watchedAssets = RadarWatchlist.sanitize(next)
        persistWatchedAssets()
        Task { await refresh() }
    }

    func addWatchedAsset(_ symbol: String) {
        let s = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !s.isEmpty, s.count <= 12 else { return }
        guard !RadarWatchlist.nonTickerBases.contains(s) else { return }
        guard !watchedAssets.contains(s) else { return }
        guard isPro || watchedAssets.count < ProLimits.freeWatchlistCap else {
            proMessage = t("pro.gate.watchlist")
            return
        }
        watchedAssets = RadarWatchlist.sanitize(watchedAssets + [s])
        persistWatchedAssets()
        Task { await refresh() }
    }

    func resetWatchedAssets() {
        watchedAssets = RadarWatchlist.default
        persistWatchedAssets()
        Task { await refresh() }
    }

    func addDraftWallet() {
        guard isPro || watchedWallets.count < ProLimits.freeWalletCap else {
            proMessage = t("pro.gate.wallets")
            let alert = IslandAlert(
                id: UUID(),
                kind: .whale,
                title: t("pro.gate.title"),
                detail: t("pro.gate.wallets"),
                createdAt: .now,
                isRead: false
            )
            present(alert)
            return
        }
        let trimmed = draftAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidAddress(trimmed, chain: draftChain) else {
            let hint: String = {
                switch draftChain {
                case .btc: t("wallets.invalidBTC")
                case .eth: t("wallets.invalidETH")
                case .sol: t("wallets.invalidSOL")
                }
            }()
            let alert = IslandAlert(
                id: UUID(),
                kind: .whale,
                title: t("wallets.invalidTitle"),
                detail: hint,
                createdAt: .now,
                isRead: false
            )
            present(alert)
            if soundEnabled { SoundPlayer.play(for: .whale) }
            return
        }
        guard !watchedWallets.contains(where: {
            $0.address.lowercased() == trimmed.lowercased() && $0.chain == draftChain
        }) else {
            return
        }

        let label = draftLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = "\(draftChain.title) Wallet"
        watchedWallets.append(
            WatchedWallet(
                id: UUID(),
                label: label.isEmpty ? fallback : label,
                address: trimmed,
                chain: draftChain
            )
        )
        persistWallets()
        draftAddress = ""
        Task { await refresh() }
    }

    func removeWallet(_ wallet: WatchedWallet) {
        watchedWallets.removeAll { $0.id == wallet.id }
        persistWallets()
        Task { await refresh() }
    }

    func simulateDeposit() {
        Task {
            let deposit = await market.simulateDeposit(wallets: watchedWallets, priceUSD: snapshot.btcPriceUSD)
            depositLog.insert(deposit, at: 0)
            let alert = IslandAlert(
                id: UUID(),
                kind: .deposit,
                title: self.t("msg.depositSimTitle"),
                detail: "\(deposit.walletLabel) +\(deposit.amountText) (≈ \(deposit.usd.usdCompact))",
                createdAt: .now,
                isRead: false
            )
            alertLog.insert(alert, at: 0)
            snapshot.status = .actionNeeded
            snapshot.radarLabel = RadarCode.deposit
            snapshot.statusDetail = self.t("msg.simDetail")
            snapshot.deposits = Array(depositLog.prefix(10))
            selectedTab = .log
            present(alert)
            if soundEnabled {
                SoundPlayer.play(for: .deposit)
            }
            if notificationsEnabled {
                await AppNotifier.notify(alert: alert, sound: false)
            }
        }
    }

    /// Demo P2P order — exercises the status card + notch without a real C2C trade.
    func simulateP2POrder() {
        let stamp = Int(Date().timeIntervalSince1970)
        let order = BinanceP2POrder(
            orderNumber: "SIM\(stamp)",
            tradeType: "SELL",
            asset: "USDT",
            fiat: "VES",
            fiatSymbol: "Bs ",
            amount: 9.39,
            totalPrice: 8_000,
            unitPrice: 851.97,
            orderStatus: "PENDING",
            createTime: .now,
            payMethodName: "Pago Móvil",
            counterPartNickName: "DemoBuyer",
            expireTime: Date().addingTimeInterval(7 * 60),
            isSimulated: true
        )
        simulatedP2POrders.removeAll { $0.isSimulated && !$0.isOpen }
        simulatedP2POrders.insert(order, at: 0)
        publishSimulatedP2P()
        let alert = makeP2PAlert(for: order)
        alertLog.insert(alert, at: 0)
        snapshot.status = .actionNeeded
        snapshot.radarLabel = RadarCode.p2p
        selectedTab = .radar
        selectedRadarSubTab = .p2p
        present(alert)
        if soundEnabled {
            SoundPlayer.play(for: .deposit)
        }
        Task {
            if notificationsEnabled {
                await AppNotifier.notify(alert: alert, sound: false)
            }
        }
    }

    /// Advance the newest demo order through NEW → PAID → RELEASE → DONE.
    func advanceSimulatedP2P() {
        guard let idx = simulatedP2POrders.firstIndex(where: \.isOpen) else { return }
        var order = simulatedP2POrders[idx]
        let nextStatus: String? = switch order.phase {
        case .pendingPayment: "BUYER_PAYED"
        case .paid: "DISTRIBUTING"
        case .distributing: "COMPLETED"
        default: nil
        }
        guard let nextStatus else { return }
        order.orderStatus = nextStatus
        if order.phase == .completed || order.phase == .cancelled {
            order.expireTime = nil
        } else if order.phase == .paid {
            order.expireTime = Date().addingTimeInterval(10 * 60)
        }
        simulatedP2POrders[idx] = order
        publishSimulatedP2P()
        let alert = makeP2PAlert(for: order)
        alertLog.insert(alert, at: 0)
        present(alert)
        if soundEnabled {
            SoundPlayer.play(for: .deposit)
        }
    }

    func clearSimulatedP2P() {
        simulatedP2POrders.removeAll()
        publishSimulatedP2P()
    }

    private func publishSimulatedP2P() {
        let api = snapshot.p2pOrders.filter { !$0.isSimulated }
        let open = api.filter(\.isOpen).sorted { $0.createTime > $1.createTime }
        let closed = api.filter { !$0.isOpen }.sorted { $0.createTime > $1.createTime }
        snapshot.p2pOrders = mergedP2PDisplayOrders(apiOpen: open, apiClosed: closed)
        let openCount = snapshot.openP2POrders.count
        snapshot.p2pStatus = openCount == 0 ? "No open orders" : "\(openCount) open"
        syncNotchMode(hovering: notchPointerInside)
    }

    private func mergedP2PDisplayOrders(
        apiOpen: [BinanceP2POrder],
        apiClosed: [BinanceP2POrder]
    ) -> [BinanceP2POrder] {
        let sims = simulatedP2POrders.sorted { $0.createTime > $1.createTime }
        var seen = Set<String>()
        var merged: [BinanceP2POrder] = []
        for order in sims + apiOpen + apiClosed {
            if seen.insert(order.orderNumber).inserted {
                merged.append(order)
            }
        }
        return Array(merged.prefix(8))
    }

    func testSound() {
        SoundPlayer.play(for: .deposit)
    }

    func quitApp() {
        stop()
        NSApplication.shared.terminate(nil)
    }

    var pillPnLText: String {
        String(format: "%+.1f%%", snapshot.pnl24hPercent)
    }

    var pillFeeText: String {
        String(format: "%.0f sat", snapshot.fee.rate)
    }

    var unreadAlertCount: Int {
        alertLog.filter { !$0.isRead }.count
    }

    private func reloadCredentialState() {
        if let cached = cachedCredentials {
            binanceAPIKeyDraft = cached.apiKey
            binanceHasCredentials = true
            binanceMessage = t("msg.apiMemory")
            return
        }
        if let local = LocalCredentialStore.load() {
            cachedCredentials = local
            binanceAPIKeyDraft = local.apiKey
            binanceHasCredentials = true
            binanceMessage = t("msg.apiReady")
            return
        }
        if let key = KeychainStore.load(.apiKey), !key.isEmpty,
           let secret = KeychainStore.load(.apiSecret), !secret.isEmpty {
            let creds = BinanceCredentials(apiKey: key, apiSecret: secret)
            cachedCredentials = creds
            binanceAPIKeyDraft = key
            binanceHasCredentials = true
            try? LocalCredentialStore.save(apiKey: key, apiSecret: secret)
            KeychainStore.clearBinanceCredentials()
            binanceMessage = t("msg.apiMigrated")
            return
        }
        binanceHasCredentials = false
    }

    private func loadCredentials() -> BinanceCredentials? {
        if let cached = cachedCredentials, cached.isComplete {
            return cached
        }
        if let local = LocalCredentialStore.load() {
            cachedCredentials = local
            return local
        }
        return nil
    }

    private func processEarnDelta(currentEarnUSD: Double) -> (alert: IslandAlert, deltaUSD: Double)? {
        if !earnBaselineDone {
            earnBaselineDone = true
            lastEarnUSD = currentEarnUSD
            return nil
        }
        guard let previous = lastEarnUSD else {
            lastEarnUSD = currentEarnUSD
            return nil
        }
        let delta = currentEarnUSD - previous
        lastEarnUSD = currentEarnUSD
        guard abs(delta) >= 1 else { return nil }

        if delta > 0 {
            return (
                IslandAlert(
                    id: UUID(),
                    kind: .earn,
                    title: t("msg.earnSubscribe"),
                    detail: "+\(delta.usdCompact) → Simple Earn (total \(currentEarnUSD.usdCompact))",
                    createdAt: .now,
                    isRead: false
                ),
                delta
            )
        }
        return (
            IslandAlert(
                id: UUID(),
                kind: .earn,
                title: t("msg.earnRedeem"),
                detail: "\(delta.usdCompact) ← Simple Earn (total \(currentEarnUSD.usdCompact))",
                createdAt: .now,
                isRead: false
            ),
            delta
        )
    }

    private enum P2PFetchOutcome {
        case skipped
        case success([BinanceP2POrder])
        case failure(String)
    }

    private func fetchP2POrdersIfEnabled(credentials: BinanceCredentials) async -> P2PFetchOutcome {
        guard thresholds.p2pAlertsEnabled else { return .skipped }
        do {
            let orders = try await binance.fetchP2POrderHistory(credentials: credentials, rows: 50)
            return .success(orders)
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    private func processP2POrders(_ orders: [BinanceP2POrder]) -> [IslandAlert] {
        if !p2pPrimed {
            for order in orders {
                seenP2POrderStatus[order.orderNumber] = order.orderStatus
            }
            p2pPrimed = true
            persistSeenP2P()
            return []
        }

        let fiatFilter = thresholds.p2pFiat.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        var changed = false
        var fresh: [IslandAlert] = []

        for order in orders {
            let prev = seenP2POrderStatus[order.orderNumber]
            let statusChanged = prev == nil || prev != order.orderStatus
            guard statusChanged else { continue }

            seenP2POrderStatus[order.orderNumber] = order.orderStatus
            changed = true

            let passesFiat = fiatFilter.isEmpty || order.fiat == fiatFilter
            guard passesFiat else { continue }

            fresh.append(makeP2PAlert(for: order))
        }

        if changed {
            // Cap stored map so it doesn't grow forever.
            if seenP2POrderStatus.count > 400 {
                let keep = Set(orders.map(\.orderNumber))
                seenP2POrderStatus = seenP2POrderStatus.filter { keep.contains($0.key) }
            }
            persistSeenP2P()
        }
        return fresh
    }

    private func makeP2PAlert(for order: BinanceP2POrder) -> IslandAlert {
        let titleKey: String = switch order.phase {
        case .pendingPayment: "msg.p2pNew"
        case .paid: "msg.p2pPaid"
        case .distributing: "msg.p2pRelease"
        case .completed: "msg.p2pDone"
        case .cancelled: "msg.p2pCancel"
        case .appeal: "msg.p2pAppeal"
        case .other: "msg.p2pStatus"
        }
        var parts = ["\(order.tradeType) \(order.amountText)"]
        if !order.fiatText.isEmpty { parts.append(order.fiatText) }
        if !order.payMethodName.isEmpty { parts.append(order.payMethodName) }
        parts.append("#\(order.shortOrderID)")
        if order.phase == .other, !order.orderStatus.isEmpty {
            parts.insert(order.orderStatus, at: 1)
        }
        return IslandAlert(
            id: UUID(),
            kind: .p2p,
            title: t(titleKey),
            detail: parts.joined(separator: " · "),
            createdAt: .now,
            isRead: false
        )
    }

    private func persistSeenP2P() {
        if let data = try? JSONEncoder().encode(seenP2POrderStatus) {
            UserDefaults.standard.set(data, forKey: Keys.seenP2P)
        }
    }

    private func processBinanceDeposits(_ deposits: [BinanceDepositRecord], prices: [String: Double]) -> [DepositEvent] {
        if !binancePrimed {
            for d in deposits {
                seenBinanceDepositIDs.insert(d.id)
            }
            binancePrimed = true
            persistSeenBinance()
            return []
        }

        var fresh: [DepositEvent] = []
        for d in deposits where d.isCompleteEnoughToAlert {
            guard !seenBinanceDepositIDs.contains(d.id) else { continue }
            seenBinanceDepositIDs.insert(d.id)
            let px = prices[d.coin] ?? 0
            fresh.append(
                DepositEvent(
                    id: "binance-\(d.id)",
                    walletLabel: "Binance Spot",
                    address: d.address,
                    asset: d.coin,
                    amount: d.amount,
                    usd: d.amount * px,
                    confirmed: d.status == 1 || d.status == 6,
                    detectedAt: d.insertTime,
                    source: .binance,
                    statusText: "\(d.statusLabel) · \(d.network)"
                )
            )
        }
        if !fresh.isEmpty {
            persistSeenBinance()
        }
        return fresh.sorted { $0.detectedAt > $1.detectedAt }
    }

    private func persistSeenBinance() {
        UserDefaults.standard.set(Array(seenBinanceDepositIDs), forKey: Keys.seenBinance)
    }

    private func persistWallets() {
        if let data = try? JSONEncoder().encode(watchedWallets) {
            UserDefaults.standard.set(data, forKey: Keys.wallets)
        }
    }

    private func persistThresholds() {
        if let data = try? JSONEncoder().encode(thresholds) {
            UserDefaults.standard.set(data, forKey: Keys.thresholds)
        }
    }

    private func persistWatchedAssets() {
        UserDefaults.standard.set(watchedAssets, forKey: Keys.watchedAssets)
    }

    private func isValidAddress(_ address: String, chain: ChainKind) -> Bool {
        switch chain {
        case .btc:
            let lower = address.lowercased()
            if lower.hasPrefix("bc1"), address.count >= 14 { return true }
            if address.hasPrefix("1") || address.hasPrefix("3"), address.count >= 26 { return true }
            return false
        case .eth:
            var a = address.lowercased()
            if a.hasPrefix("0x") { a = String(a.dropFirst(2)) }
            guard a.count == 40 else { return false }
            return a.allSatisfy { $0.isHexDigit }
        case .sol:
            // Base58-ish length check (no full checksum without dependency).
            guard address.count >= 32, address.count <= 44 else { return false }
            let allowed = CharacterSet.alphanumerics.subtracting(CharacterSet(charactersIn: "0OIl"))
            return address.unicodeScalars.allSatisfy { allowed.contains($0) }
        }
    }

    private func apply(snapshot next: MarketSnapshot, newDeposits: [DepositEvent]) {
        var next = next
        if !newDeposits.isEmpty {
            depositLog.insert(contentsOf: newDeposits, at: 0)
            if depositLog.count > 50 {
                depositLog = Array(depositLog.prefix(50))
            }
        }
        next.deposits = Array(depositLog.prefix(10))
        snapshot = next

        var fresh: [IslandAlert] = []
        for alert in next.alerts {
            let signature = alertSignature(alert)
            if !knownSignatures.contains(signature) {
                knownSignatures.insert(signature)
                fresh.append(alert)
            }
        }

        pruneTransientSignatures(currentAlerts: next.alerts)
        fresh.sort { alertPriority($0) < alertPriority($1) }

        if !fresh.isEmpty {
            alertLog.insert(contentsOf: fresh, at: 0)
            if alertLog.count > 40 {
                alertLog = Array(alertLog.prefix(40))
            }
            present(fresh[0])
            if soundEnabled {
                SoundPlayer.play(for: fresh[0].kind)
            }
            if notificationsEnabled {
                Task {
                    for alert in fresh.prefix(3) where shouldNotify(alert) {
                        await AppNotifier.notify(alert: alert, sound: false)
                    }
                }
            }
        }
    }

    private func alertSignature(_ alert: IslandAlert) -> String {
        switch alert.kind {
        case .pnl, .gas, .health:
            return "\(alert.kind.rawValue)|\(alert.title)"
        case .earn where alert.title.hasPrefix("Unlock"):
            let asset = alert.detail.split(separator: "·").first.map(String.init)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? alert.detail
            return "earn|unlock|\(asset)"
        default:
            return "\(alert.kind.rawValue)|\(alert.title)|\(alert.detail.prefix(48))"
        }
    }

    private func pruneTransientSignatures(currentAlerts: [IslandAlert]) {
        let live = Set(
            currentAlerts
                .filter { $0.kind == .pnl || $0.kind == .gas || $0.kind == .health }
                .map { alertSignature($0) }
        )
        knownSignatures = Set(knownSignatures.filter { sig in
            if sig.hasPrefix("pnl|") || sig.hasPrefix("gas|") || sig.hasPrefix("health|") {
                return live.contains(sig)
            }
            return true
        })
    }

    private func alertPriority(_ alert: IslandAlert) -> Int {
        switch alert.kind {
        case .deposit: 0
        case .p2p: 0
        case .health: 1
        case .earn: 2
        case .pnl: 3
        case .gas: 4
        case .whale: 5
        }
    }

    private func shouldNotify(_ alert: IslandAlert) -> Bool {
        let signature = alertSignature(alert)
        let now = Date()
        if let until = notifyCooldownUntil[signature], until > now {
            return false
        }

        let quiet = thresholds.isInQuietHours()
        switch alert.kind {
        case .deposit, .p2p:
            break // always (subject to cooldown) — critical ops
        case .earn:
            if quiet { return false }
        case .gas, .pnl, .health:
            if quiet { return false }
        case .whale:
            return false
        }

        let cooldown = TimeInterval(max(5, thresholds.cooldownMinutes) * 60)
        notifyCooldownUntil[signature] = now.addingTimeInterval(cooldown)
        return true
    }

    private func present(_ alert: IslandAlert) {
        bannerAlert = alert
        pillPulse = true
        // Always expand immediately — even if the content panel is open
        // (SIMULATE_DEPOSIT / live alerts). Do not wait for hover or panel close.
        fireNotchAlertExpand()

        // Keep banner/pulse aligned with notch alert burst (~4.2s expand + read).
        bannerTask?.cancel()
        bannerTask = Task {
            try? await Task.sleep(for: .milliseconds(4_800))
            if !Task.isCancelled {
                bannerAlert = nil
            }
        }

        pulseTask?.cancel()
        pulseTask = Task {
            try? await Task.sleep(for: .milliseconds(4_200))
            if !Task.isCancelled {
                pillPulse = false
            }
        }
    }

    private func fireNotchAlertExpand() {
        alertNotchTask?.cancel()
        alertNotchExpanded = true
        // Resize the NSPanel from here — don't wait for the SwiftUI view to notice.
        onNotchModeChange?(.expanded)

        alertNotchTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(4_200))
            guard !Task.isCancelled else { return }
            alertNotchExpanded = false
            if notchPointerInside {
                onNotchModeChange?(.expanded)
            } else if snapshot.openP2POrders.first != nil {
                // Stay docked with the live timer — don't fully collapse like Binance's floating card.
                onNotchModeChange?(.p2pDock)
            } else {
                onNotchModeChange?(.collapsed)
            }
        }
    }
}

private extension Double {
    var usdCompact: String {
        if abs(self) >= 1000 {
            return String(format: "$%.2fk", self / 1000)
        }
        return String(format: "$%.2f", self)
    }
}
