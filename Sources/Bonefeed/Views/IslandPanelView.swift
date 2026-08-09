import SwiftUI

struct IslandPanelView: View {
    @Bindable var store: AppStore
    private var p: ThemePalette { store.palette }
    @State private var showSplash = true
    @State private var lastToken: UInt = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [p.bg, p.bgMid, p.bg],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            CyberGrid()
                .opacity(p.gridOpacity)
                .allowsHitTesting(false)
            RetroScanlines()
                .opacity(p.scanlineOpacity)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                if let banner = store.bannerAlert {
                    RetroBanner(alert: banner)
                }
                tabBar
                NeonRule(cyan: true)

                Group {
                    if store.showOnboarding {
                        OnboardingGuideView(store: store)
                    } else {
                        switch store.selectedTab {
                        case .radar: RadarPage(store: store)
                        case .spot: SpotPage(store: store)
                        case .earn: EarnPage(store: store)
                        case .log: LogPage(store: store)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                NeonRule()
                footer
            }
            .opacity(showSplash ? 0 : 1)
            .allowsHitTesting(!showSplash)

            if showSplash {
                IslandSplashView {
                    showSplash = false
                }
                .zIndex(10)
            }
        }
        .frame(minWidth: 380, minHeight: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.chainPalette, p)
        .preferredColorScheme(store.appTheme.colorScheme)
        .onChange(of: store.appTheme) { _, _ in
            IslandUIController.shared.syncPanelBackground()
        }
        .onAppear {
            lastToken = store.panelOpenToken
            if store.skipNextSplash {
                store.skipNextSplash = false
                showSplash = false
            } else {
                showSplash = true
            }
        }
        .onChange(of: store.panelOpenToken) { _, token in
            guard token != lastToken else { return }
            lastToken = token
            if store.skipNextSplash {
                store.skipNextSplash = false
                showSplash = false
            } else {
                showSplash = true
            }
        }
    }

    /// In-content top bar — plain text/icons, no toolbar glass pill.
    private var topBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 7) {
                if let logo = AppLogoImage.load() {
                    Image(nsImage: logo)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 16, height: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                }
                Text(Brand.nameUpper)
                    .font(IslandTheme.monoTitle)
                    .foregroundStyle(p.accent)
                    .tracking(1.2)
                Text(store.appTheme.title)
                    .font(IslandTheme.monoSmall)
                    .foregroundStyle(p.cool.opacity(0.9))
            }

            Spacer(minLength: 8)

            Button {
                store.forceRefresh()
            } label: {
                HStack(spacing: 5) {
                    if store.isRefreshing {
                        Text("… SYNC")
                    } else {
                        Text("▶ LIVE")
                    }
                    if store.isPaused {
                        Text("PAUSED")
                            .foregroundStyle(p.warn.opacity(0.95))
                    } else if let last = store.lastRefreshAt {
                        Text(last, style: .time)
                            .foregroundStyle(p.muted)
                    }
                }
                .font(IslandTheme.monoBold)
                .foregroundStyle(store.isPaused ? p.warn : p.cool)
            }
            .buttonStyle(.plain)
            .help(store.t("panel.refreshHint"))

            Button {
                store.togglePanelPin()
            } label: {
                Image(systemName: store.isPanelPinned ? "pin.fill" : "pin")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(store.isPanelPinned ? p.warn : p.muted)
            }
            .buttonStyle(.plain)
            .help(store.isPanelPinned ? store.t("panel.unpin") : store.t("panel.pin"))

            Button {
                store.openAppSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(p.cool)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(AppStore.PanelTab.allCases) { tab in
                let selected = store.selectedTab == tab
                let unread = tab == .log ? store.unreadAlertCount : 0
                Button {
                    store.selectedTab = tab
                    if tab == .log { store.markAlertsRead() }
                } label: {
                    HStack(spacing: 5) {
                        Text(tab.title)
                            .font(IslandTheme.monoBold)
                        if unread > 0 {
                            Text("\(unread)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(selected ? p.bg : p.danger)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(selected ? p.bg.opacity(0.22) : p.danger.opacity(0.2))
                        }
                    }
                    .foregroundStyle(selected ? p.bg : p.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(selected ? p.accent : Color.clear)
                    .overlay(
                        Rectangle()
                            .stroke(selected ? p.cool.opacity(0.7) : p.strokeDim, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(store.showOnboarding)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    /// Ops strip: pause / sound / quit. Sync is topBar LIVE; settings is topBar only.
    private var footer: some View {
        HStack(spacing: 12) {
            Button(store.isPaused ? "▶ RUN" : "■ HALT") {
                store.togglePause()
            }
            .buttonStyle(.plain)
            .font(IslandTheme.monoBold)
            .foregroundStyle(store.isPaused ? p.cool : p.warn)
            .help(store.isPaused ? "Resume polling" : "Pause polling")

            Button(store.soundEnabled ? "♪ SOUND ON" : "♪ SOUND OFF") {
                store.soundEnabled.toggle()
            }
            .buttonStyle(.plain)
            .font(IslandTheme.monoBold)
            .foregroundStyle(store.soundEnabled ? p.accent : p.muted)

            Spacer()

            Button("✕ QUIT") {
                store.quitApp()
            }
            .buttonStyle(.plain)
            .font(IslandTheme.monoBold)
            .foregroundStyle(p.danger)
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(p.panel.opacity(0.45))
    }
}

// MARK: - Pages

private struct RadarPage: View {
    @Bindable var store: AppStore
    private var p: ThemePalette { store.palette }

    var body: some View {
        VStack(spacing: 0) {
            radarSubBar
            NeonRule(cyan: true)
            Group {
                switch store.selectedRadarSubTab {
                case .overview:
                    radarOverview
                case .p2p:
                    RadarP2PPage(store: store)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var radarSubBar: some View {
        HStack(spacing: 4) {
            ForEach(AppStore.RadarSubTab.allCases) { sub in
                let selected = store.selectedRadarSubTab == sub
                let openCount = store.snapshot.openP2POrders.count
                Button {
                    store.selectedRadarSubTab = sub
                } label: {
                    HStack(spacing: 5) {
                        Text(sub.title)
                            .font(IslandTheme.monoBold)
                        if sub == .p2p, openCount > 0 {
                            Text("\(openCount)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(selected ? p.bg : p.cool)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background((selected ? p.bg.opacity(0.25) : p.cool.opacity(0.18)))
                                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        }
                    }
                    .foregroundStyle(selected ? p.bg : p.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(selected ? p.cool.opacity(0.92) : Color.clear)
                    .overlay(
                        Rectangle()
                            .stroke(selected ? p.accent.opacity(0.55) : p.strokeDim, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(p.panel.opacity(0.35))
    }

    private var radarOverview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                RetroSection(title: "PORTFOLIO") {
                    let spotUSD = store.snapshot.binanceLiquidHoldings.reduce(0) { $0 + $1.usd }
                    HStack(spacing: 12) {
                        RetroStat(
                            label: "TOTAL",
                            value: store.snapshot.binanceConnected
                                ? store.snapshot.binancePortfolioUSD.asUSD
                                : "--"
                        )
                        RetroStat(
                            label: "SPOT",
                            value: store.snapshot.binanceConnected ? spotUSD.asUSD : "--"
                        )
                        RetroStat(
                            label: "EARN",
                            value: store.snapshot.binanceConnected
                                ? store.snapshot.binanceEarnUSD.asUSD
                                : "--"
                        )
                        RetroStat(
                            label: "PnL24",
                            value: store.snapshot.binanceConnected
                                ? String(format: "%+.1f%%", store.snapshot.pnl24hPercent)
                                : "--",
                            accent: p.pnlColor(store.snapshot.pnl24hPercent)
                        )
                    }
                    if store.snapshot.binanceConnected {
                        let mkt = store.snapshot.marketChange24hPercent
                        let pnlSource = store.snapshot.portfolioPnL24hPercent != nil
                            ? store.t("panel.pnlBag")
                            : store.t("panel.pnlMkt")
                        Text("PnL \(pnlSource) · BTC \(String(format: "%+.1f%%", mkt))\(store.snapshot.userStreamLive ? " · stream" : "") · \(store.t("panel.tapLive"))")
                            .font(IslandTheme.monoSmall)
                            .foregroundStyle(p.muted)
                        if let earnErr = store.snapshot.earnStatus {
                            Text(earnErr)
                                .font(IslandTheme.monoSmall)
                                .foregroundStyle(p.warn)
                        }
                    } else {
                        Text(store.t("panel.apiOff"))
                            .font(IslandTheme.monoSmall)
                            .foregroundStyle(p.warn)
                    }
                }

                RetroSection(title: "MARKETS") {
                    if store.snapshot.marketTicks.isEmpty {
                        Text(store.t("panel.marketsEmpty"))
                            .font(IslandTheme.mono)
                            .foregroundStyle(p.muted)
                    } else {
                        ForEach(store.snapshot.marketTicks.prefix(8)) { tick in
                            HStack {
                                Text(tick.symbol.padding(toLength: 5, withPad: " ", startingAt: 0))
                                    .font(IslandTheme.monoBold)
                                    .foregroundStyle(p.text)
                                Spacer()
                                Text(tick.priceText)
                                    .font(IslandTheme.mono)
                                    .foregroundStyle(p.muted)
                                Text(tick.changeText)
                                    .font(IslandTheme.monoBold)
                                    .foregroundStyle(p.pnlColor(tick.change24hPercent))
                                    .frame(minWidth: 64, alignment: .trailing)
                            }
                        }
                    }
                }

                RetroSection(title: "SIGNALS") {
                    let signals = store.snapshot.activeSignals.prefix(4)
                    if signals.isEmpty {
                        Text("—")
                            .font(IslandTheme.mono)
                            .foregroundStyle(p.muted)
                    } else {
                        ForEach(Array(signals)) { signal in
                            HStack(alignment: .top, spacing: 8) {
                                Text(signalGlyph(signal.kind))
                                    .font(IslandTheme.monoBold)
                                    .foregroundStyle(signalColor(signal.kind))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(signal.title.uppercased())
                                        .font(IslandTheme.monoBold)
                                        .foregroundStyle(p.text)
                                    Text(signal.detail)
                                        .font(IslandTheme.monoSmall)
                                        .foregroundStyle(p.muted)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }

                if let detail = store.snapshot.statusDetail {
                    Text("// \(detail)")
                        .font(IslandTheme.monoSmall)
                        .foregroundStyle(p.muted)
                }
            }
            .padding(12)
        }
    }

    private func signalGlyph(_ kind: MarketSignal.Kind) -> String {
        switch kind {
        case .calm: "·"
        case .dump: "▼"
        case .pump: "▲"
        case .feeHigh: "!"
        case .health: "♥"
        }
    }

    private func signalColor(_ kind: MarketSignal.Kind) -> Color {
        switch kind {
        case .calm: p.accent
        case .dump: p.danger
        case .pump: p.gain
        case .feeHigh: p.warn
        case .health: p.danger
        }
    }
}

private struct RadarP2PPage: View {
    @Bindable var store: AppStore
    private var p: ThemePalette { store.palette }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let live = store.snapshot.openP2POrders.first {
                    RetroSection(title: "LIVE ORDER") {
                        P2POrderStatusCard(order: live, compact: false)
                    }
                }

                RetroSection(title: "P2P ORDERS") {
                    if !store.isPro && store.snapshot.p2pOrders.filter({ !$0.isSimulated }).isEmpty {
                        ProPanelLock(store: store)
                    } else if !store.thresholds.p2pAlertsEnabled
                                && store.snapshot.p2pOrders.filter({ !$0.isSimulated }).isEmpty {
                        Text(store.t("panel.p2pOff"))
                            .font(IslandTheme.mono)
                            .foregroundStyle(p.muted)
                    } else if !store.snapshot.binanceConnected
                                && store.snapshot.p2pOrders.filter({ !$0.isSimulated }).isEmpty {
                        Text(store.t("panel.noApi"))
                            .font(IslandTheme.mono)
                            .foregroundStyle(p.warn)
                    } else if store.snapshot.p2pOrders.isEmpty {
                        Text(store.snapshot.p2pStatus ?? store.t("panel.p2pEmpty"))
                            .font(IslandTheme.mono)
                            .foregroundStyle(p.muted)
                    } else {
                        if let status = store.snapshot.p2pStatus {
                            Text(status.uppercased())
                                .font(IslandTheme.monoSmall)
                                .foregroundStyle(p.cool)
                        }
                        ForEach(store.snapshot.p2pOrders) { order in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(order.phase.shortLabel.padding(toLength: 7, withPad: " ", startingAt: 0))
                                    .font(IslandTheme.monoBold)
                                    .foregroundStyle(phaseColor(order.phase))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(order.tradeType) \(order.amountText)")
                                        .font(IslandTheme.monoBold)
                                        .foregroundStyle(p.text)
                                    HStack(spacing: 6) {
                                        if !order.fiatText.isEmpty {
                                            Text(order.fiatText)
                                        }
                                        if !order.payMethodName.isEmpty {
                                            Text(order.payMethodName)
                                        }
                                        Text("#\(order.shortOrderID)")
                                        if order.isSimulated {
                                            Text("DEMO")
                                                .foregroundStyle(p.warn)
                                        }
                                    }
                                    .font(IslandTheme.monoSmall)
                                    .foregroundStyle(p.muted)
                                    .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                if order.isOpen {
                                    Text("LIVE")
                                        .font(IslandTheme.monoSmall)
                                        .foregroundStyle(p.cool)
                                }
                            }
                        }
                    }
                }

                RetroSection(title: "DEMO") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.t("panel.p2pDemoHint"))
                            .font(IslandTheme.monoSmall)
                            .foregroundStyle(p.muted)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            Button(store.t("panel.simulateP2P")) {
                                store.simulateP2POrder()
                            }
                            .buttonStyle(.plain)
                            .font(IslandTheme.monoBold)
                            .foregroundStyle(p.cool)

                            if store.simulatedP2POrders.contains(where: \.isOpen) {
                                Button(store.t("panel.advanceP2P")) {
                                    store.advanceSimulatedP2P()
                                }
                                .buttonStyle(.plain)
                                .font(IslandTheme.monoBold)
                                .foregroundStyle(p.warn)

                                Button(store.t("panel.clearP2PDemo")) {
                                    store.clearSimulatedP2P()
                                }
                                .buttonStyle(.plain)
                                .font(IslandTheme.monoBold)
                                .foregroundStyle(p.danger)
                            }
                        }
                    }
                }

                RetroSection(title: "HINT") {
                    Text(store.t("panel.p2pHint"))
                        .font(IslandTheme.monoSmall)
                        .foregroundStyle(p.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
        }
    }

    private func phaseColor(_ phase: BinanceP2POrder.Phase) -> Color {
        switch phase {
        case .pendingPayment: p.warn
        case .paid: p.cool
        case .distributing: p.accent
        case .completed: p.muted
        case .cancelled: p.muted
        case .appeal: p.danger
        case .other: p.warn
        }
    }
}

private struct SpotPage: View {
    @Bindable var store: AppStore
    private var p: ThemePalette { store.palette }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                RetroSection(title: "SPOT / FUNDING") {
                    if !store.isPro {
                        ProPanelLock(store: store)
                    } else if !store.snapshot.binanceConnected {
                        Text(store.t("panel.noApi"))
                            .font(IslandTheme.mono)
                            .foregroundStyle(p.warn)
                    } else {
                        if let fundErr = store.snapshot.fundingStatus {
                            Text(fundErr)
                                .font(IslandTheme.monoSmall)
                                .foregroundStyle(p.warn)
                        }
                        if store.snapshot.binanceLiquidHoldings.isEmpty {
                            Text(store.t("panel.spotEmpty"))
                                .font(IslandTheme.mono)
                                .foregroundStyle(p.muted)
                        } else {
                            ForEach(store.snapshot.binanceLiquidHoldings.prefix(20)) { h in
                                HStack {
                                    Text(h.asset.padding(toLength: 8, withPad: " ", startingAt: 0))
                                        .font(IslandTheme.monoBold)
                                        .foregroundStyle(p.text)
                                    Text(h.wallet.uppercased())
                                        .font(IslandTheme.monoSmall)
                                        .foregroundStyle(p.muted)
                                    Spacer()
                                    Text(h.amountText)
                                        .font(IslandTheme.mono)
                                        .foregroundStyle(p.muted)
                                    Text(h.usd > 0 ? h.usd.asUSD : "--")
                                        .font(IslandTheme.monoBold)
                                        .foregroundStyle(p.accent)
                                        .frame(minWidth: 58, alignment: .trailing)
                                }
                            }
                        }
                    }
                }

                RetroSection(title: "ON-CHAIN WATCH") {
                    ForEach(store.snapshot.wallets) { w in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("\(w.chain) \(w.label.uppercased())")
                                    .font(IslandTheme.monoBold)
                                    .foregroundStyle(p.text)
                                Spacer()
                                Text(w.nativeText)
                                    .font(IslandTheme.mono)
                                    .foregroundStyle(p.muted)
                            }
                            HStack {
                                Text(w.shortAddress)
                                    .font(IslandTheme.monoSmall)
                                    .foregroundStyle(p.muted)
                                    .textSelection(.enabled)
                                Spacer()
                                if let hf = w.healthText {
                                    Text(hf)
                                        .font(IslandTheme.monoBold)
                                        .foregroundStyle(
                                            (w.healthFactor ?? 99) < store.thresholds.healthFactorWarn
                                                ? p.danger : p.cool
                                        )
                                }
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
    }
}

private struct EarnPage: View {
    let store: AppStore
    private var p: ThemePalette { store.palette }

    var body: some View {
        if !store.isPro {
            VStack(spacing: 12) {
                ProPanelLock(store: store)
                Spacer(minLength: 0)
            }
            .padding(16)
        } else {
            earnContent
        }
    }

    private var earnContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                RetroSection(title: "EARN SUMMARY") {
                    HStack(spacing: 16) {
                        RetroStat(label: "LOCKED_IN", value: store.snapshot.binanceEarnUSD.asUSD)
                        RetroStat(
                            label: "YDAY_REWARD",
                            value: store.snapshot.earnYesterdayRewardsUSD > 0
                                ? "+\(store.snapshot.earnYesterdayRewardsUSD.asUSD)"
                                : "--",
                            accent: p.warn
                        )
                    }
                    if let earnErr = store.snapshot.earnStatus {
                        Text(earnErr)
                            .font(IslandTheme.monoSmall)
                            .foregroundStyle(p.warn)
                    }
                }

                if !store.snapshot.earnOpportunities.isEmpty {
                    RetroSection(title: "BETTER APR") {
                        ForEach(store.snapshot.earnOpportunities.prefix(5)) { opp in
                            HStack {
                                Text(opp.asset)
                                    .font(IslandTheme.monoBold)
                                    .foregroundStyle(p.text)
                                Spacer()
                                Text(String(format: "%.2f→%.2f%%", opp.currentAprPercent, opp.bestAprPercent))
                                    .font(IslandTheme.mono)
                                    .foregroundStyle(p.muted)
                                Text(String(format: "+%.2f", opp.gainPercent))
                                    .font(IslandTheme.monoBold)
                                    .foregroundStyle(p.accent)
                            }
                        }
                    }
                }

                RetroSection(title: "POSITIONS") {
                    if store.snapshot.earnPositions.isEmpty {
                        Text(store.snapshot.binanceConnected
                             ? store.t("panel.noEarn")
                             : store.t("panel.noApi"))
                            .font(IslandTheme.mono)
                            .foregroundStyle(p.muted)
                    } else {
                        ForEach(store.snapshot.earnPositions.prefix(20)) { pos in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(pos.asset)
                                        .font(IslandTheme.monoBold)
                                        .foregroundStyle(p.text)
                                    Text(pos.kind.label.uppercased())
                                        .font(IslandTheme.monoSmall)
                                        .foregroundStyle(pos.kind == .locked ? p.warn : p.accent)
                                    Spacer()
                                    if let apr = pos.aprText {
                                        Text(apr)
                                            .font(IslandTheme.monoBold)
                                            .foregroundStyle(p.warn)
                                    }
                                }
                                HStack {
                                    Text(pos.amountText)
                                        .font(IslandTheme.mono)
                                        .foregroundStyle(p.muted)
                                    Spacer()
                                    Text(pos.usd.asUSD)
                                        .font(IslandTheme.monoBold)
                                        .foregroundStyle(p.cool)
                                }
                                HStack(spacing: 10) {
                                    if let y = pos.yesterdayRewardsUSD, y > 0 {
                                        Text("YDAY +\(y.asUSD)")
                                            .font(IslandTheme.monoSmall)
                                            .foregroundStyle(p.accent)
                                    }
                                    if let unlock = pos.unlockText {
                                        Text(unlock.uppercased())
                                            .font(IslandTheme.monoSmall)
                                            .foregroundStyle((pos.daysRemaining ?? 99) <= 3 ? p.danger : p.muted)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            if pos.id != store.snapshot.earnPositions.prefix(20).last?.id {
                                RetroRule()
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
    }
}

private struct LogPage: View {
    let store: AppStore
    private var p: ThemePalette { store.palette }

    var body: some View {
        VStack(spacing: 0) {
            if store.depositLog.isEmpty && store.alertLog.isEmpty {
                VStack(spacing: 12) {
                    Text(store.t("panel.logEmpty"))
                        .font(IslandTheme.monoTitle)
                        .foregroundStyle(p.muted)
                    Text(store.t("panel.logHint"))
                        .font(IslandTheme.monoSmall)
                        .foregroundStyle(p.muted)
                    Button(store.t("panel.simulate")) {
                        store.simulateDeposit()
                    }
                    .buttonStyle(.plain)
                    .font(IslandTheme.monoBold)
                    .foregroundStyle(p.warn)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        RetroSection(title: "EVENTS") {
                            ForEach(store.depositLog.prefix(30)) { d in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(d.title.uppercased())
                                            .font(IslandTheme.monoBold)
                                            .foregroundStyle(p.text)
                                        Spacer()
                                        Text(d.source.rawValue.uppercased())
                                            .font(IslandTheme.monoSmall)
                                            .foregroundStyle(p.accent)
                                    }
                                    Text("+\(d.amountText)  ≈ \(d.usd.asUSD)  ·  \(d.statusText)")
                                        .font(IslandTheme.monoSmall)
                                        .foregroundStyle(p.muted)
                                }
                                RetroRule()
                            }
                        }
                    }
                    .padding(12)
                }

                Button(store.t("panel.clearLog")) {
                    store.dismissAlerts()
                }
                .buttonStyle(.plain)
                .font(IslandTheme.monoBold)
                .foregroundStyle(p.accent)
                .padding(.bottom, 10)
            }
        }
    }
}

// MARK: - Cyber / 8-bit primitives

private struct ProPanelLock: View {
    let store: AppStore
    private var p: ThemePalette { store.palette }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "star.circle.fill")
                    .foregroundStyle(p.warn)
                Text("PRO")
                    .font(IslandTheme.monoBold)
                    .foregroundStyle(p.warn)
            }
            Text(store.t("pro.panelLock"))
                .font(IslandTheme.monoSmall)
                .foregroundStyle(p.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button(store.proBuyLabel) {
                Task { await store.purchasePro() }
            }
            .buttonStyle(.plain)
            .font(IslandTheme.monoBold)
            .foregroundStyle(p.accent)
            .disabled(store.proStore.isPurchasing)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(p.bg.opacity(0.45))
        .overlay(Rectangle().stroke(p.strokeDim, lineWidth: 1))
    }
}

private struct RetroSection<Content: View>: View {
    @Environment(\.chainPalette) private var p
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("◆")
                    .font(IslandTheme.monoBold)
                    .foregroundStyle(p.cool)
                Text(title)
                    .font(IslandTheme.monoBold)
                    .foregroundStyle(p.accent)
                    .shadow(color: p.accent.opacity(p.glow * 0.6), radius: p.glow * 2)
                    .tracking(0.8)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [p.accent.opacity(0.45), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
            }
            content
        }
    }
}

private struct RetroStat: View {
    @Environment(\.chainPalette) private var p
    let label: String
    let value: String
    var accent: Color? = nil

    var body: some View {
        let color = accent ?? p.cool
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(IslandTheme.monoSmall)
                .foregroundStyle(p.muted)
            Text(value)
                .font(IslandTheme.monoHero)
                .foregroundStyle(color)
                .shadow(color: color.opacity(p.glow * 0.55), radius: p.glow * 3)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NeonRule: View {
    @Environment(\.chainPalette) private var p
    var cyan: Bool = false

    var body: some View {
        let c = cyan ? p.cool : p.accent
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [c.opacity(0.12), c.opacity(0.55 + p.glow * 0.3), c.opacity(0.12)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .shadow(color: c.opacity(p.glow * 0.5), radius: p.glow * 2)
    }
}

private struct RetroRule: View {
    var body: some View {
        NeonRule()
    }
}

private struct RetroBanner: View {
    @Environment(\.chainPalette) private var p
    let alert: IslandAlert

    var body: some View {
        HStack {
            Text("⚠")
                .font(IslandTheme.monoBold)
            Text("\(alert.title.uppercased()) :: \(alert.detail)")
                .font(IslandTheme.monoSmall)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .foregroundStyle(p.bg)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(p.warn)
    }
}

private struct RetroLink: View {
    let title: String
    let color: Color
    let action: () -> Void

    init(_ title: String, color: Color, action: @escaping () -> Void) {
        self.title = title
        self.color = color
        self.action = action
    }

    var body: some View {
        Button("▸ \(title)") { action() }
            .buttonStyle(.plain)
            .font(IslandTheme.monoBold)
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.4), radius: 2)
    }
}

private struct RetroToggle: View {
    @Environment(\.chainPalette) private var p
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack {
                Text(title)
                    .font(IslandTheme.monoBold)
                    .foregroundStyle(p.text)
                Spacer()
                Text(isOn ? "≪ON≫" : "≪OFF≫")
                    .font(IslandTheme.monoBold)
                    .foregroundStyle(isOn ? p.cool : p.muted)
                    .shadow(color: isOn ? p.cool.opacity(p.glow * 0.5) : .clear, radius: p.glow * 2)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct RetroStepper: View {
    @Environment(\.chainPalette) private var p
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    var body: some View {
        HStack {
            Text(title)
                .font(IslandTheme.mono)
                .foregroundStyle(p.muted)
            Spacer()
            Button("◀") { value = max(range.lowerBound, value - step) }
                .buttonStyle(.plain)
                .font(IslandTheme.monoBold)
                .foregroundStyle(p.accent)
            Text(display)
                .font(IslandTheme.monoBold)
                .foregroundStyle(p.cool)
                .frame(minWidth: 52)
            Button("▶") { value = min(range.upperBound, value + step) }
                .buttonStyle(.plain)
                .font(IslandTheme.monoBold)
                .foregroundStyle(p.accent)
        }
    }

    private var display: String {
        unit == "%"
            ? String(format: "%.0f%%", value)
            : String(format: "%.0f %@", value, unit)
    }
}

private struct RetroScanlines: View {
    var body: some View {
        Canvas { context, size in
            for y in stride(from: 0, through: size.height, by: 3) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.black), lineWidth: 1)
            }
        }
    }
}

private struct CyberGrid: View {
    @Environment(\.chainPalette) private var p

    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 16
            let a = p.accent.opacity(0.35)
            let c = p.cool.opacity(0.25)
            for x in stride(from: 0, through: size.width, by: step) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(a), lineWidth: 0.5)
            }
            for y in stride(from: 0, through: size.height, by: step) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(c), lineWidth: 0.5)
            }
        }
    }
}

private extension Double {
    var asUSD: String {
        abs(self) >= 1000
            ? String(format: "$%.2fk", self / 1000)
            : String(format: "$%.2f", self)
    }

    var asUSDPrice: String {
        String(format: "$%.0f", self)
    }
}
