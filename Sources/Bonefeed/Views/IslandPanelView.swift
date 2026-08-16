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
                IslandSplashView(bootLabel: store.t("panel.boot")) {
                    store.splashShownThisSession = true
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
            resolveSplash()
        }
        .onChange(of: store.panelOpenToken) { _, token in
            guard token != lastToken else { return }
            lastToken = token
            resolveSplash()
        }
    }

    private func resolveSplash() {
        if store.skipNextSplash {
            store.skipNextSplash = false
            showSplash = false
            return
        }
        if store.splashShownThisSession {
            showSplash = false
            return
        }
        showSplash = true
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
                        Text(store.t("panel.sync"))
                    } else {
                        Text(store.t("panel.live"))
                    }
                    if store.isPaused {
                        Text(store.t("panel.paused"))
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
                case .signals:
                    RadarSignalsPage(store: store)
                case .p2p:
                    RadarP2PPage(store: store)
                case .lab:
                    RadarBrokerBotPage(store: store)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var radarSubBar: some View {
        HStack(spacing: 4) {
            ForEach(store.visibleRadarSubTabs) { sub in
                let selected = store.selectedRadarSubTab == sub
                let openCount = store.snapshot.openP2POrders.count
                let hotSignals = store.snapshot.activeSignals.filter { $0.kind != .calm }.count
                let labTone = sub == .lab
                Button {
                    store.selectedRadarSubTab = sub
                } label: {
                    HStack(spacing: 5) {
                        Text(store.t(sub.titleKey))
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
                        if sub == .signals, hotSignals > 0 {
                            Text("\(hotSignals)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(selected ? p.bg : p.warn)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background((selected ? p.bg.opacity(0.25) : p.warn.opacity(0.22)))
                                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        }
                        if sub == .lab {
                            Text("AI")
                                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                .foregroundStyle(selected ? p.bg : p.accent)
                        }
                    }
                    .foregroundStyle(selected ? p.bg : (labTone ? p.accent : p.muted))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(selected ? (labTone ? p.accent.opacity(0.92) : p.cool.opacity(0.92)) : Color.clear)
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
                    let signals = store.snapshot.activeSignals.prefix(3)
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
                    Button {
                        store.openSignalsDesk()
                    } label: {
                        Text(store.isVIP ? store.t("signals.openDesk") : store.t("signals.openDeskLocked"))
                            .font(IslandTheme.monoSmall)
                            .foregroundStyle(p.cool)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
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

/// Visual VIP / signal desk — early warnings, not predictions.
private struct RadarSignalsPage: View {
    @Bindable var store: AppStore
    private var p: ThemePalette { store.palette }
    @State private var pulse = false

    private var desk: AlertThresholds { store.signalDeskThresholds }
    private var tightOn: Bool { store.isVIP && store.thresholds.vipDeskEnabled }
    private var ticks: [AssetTick] { store.snapshot.marketTicks }
    private var liveSignals: [MarketSignal] {
        store.snapshot.activeSignals.filter { $0.kind != .calm }
    }
    private var rankedTicks: [AssetTick] {
        ticks.sorted {
            store.signalProximity(change24h: $0.change24hPercent).progress
                > store.signalProximity(change24h: $1.change24hPercent).progress
        }
    }
    private var hottest: AssetTick? { rankedTicks.first }
    private var firedCount: Int {
        rankedTicks.filter { store.signalProximity(change24h: $0.change24hPercent).fired }.count
    }
    private var heatAvg: Double {
        guard !rankedTicks.isEmpty else { return 0 }
        let sum = rankedTicks.reduce(0.0) {
            $0 + min(1, store.signalProximity(change24h: $1.change24hPercent).progress)
        }
        return sum / Double(rankedTicks.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                deskHero
                if store.thresholds.isInQuietHours() {
                    quietBanner
                }
                if store.isVIP {
                    heatStats
                    heatGrid
                    if let hot = hottest, store.signalProximity(change24h: hot.change24hPercent).fired {
                        actionStrip(for: hot)
                    }
                    liveFeed
                    pingHistory
                } else {
                    lockedVIPPreview
                }
                Text(store.t("signals.disclaimer"))
                    .font(IslandTheme.monoSmall)
                    .foregroundStyle(p.muted.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var quietBanner: some View {
        HStack(spacing: 8) {
            Text("☾")
                .foregroundStyle(p.cool)
            Text(store.t("signals.quietOn"))
                .font(IslandTheme.monoSmall)
                .foregroundStyle(p.muted)
            Spacer()
        }
        .padding(8)
        .background(p.cool.opacity(0.1))
        .overlay(Rectangle().stroke(p.cool.opacity(0.3), lineWidth: 1))
    }

    private var lockedVIPPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.t("signals.lockedTitle"))
                .font(IslandTheme.monoBold)
                .foregroundStyle(p.warn)
            Text(store.t("signals.lockedBody"))
                .font(IslandTheme.monoSmall)
                .foregroundStyle(p.muted)
                .fixedSize(horizontal: false, vertical: true)

            ZStack {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(rankedTicks.prefix(4)) { tick in
                        heatTile(tick)
                    }
                }
                .blur(radius: 2.2)
                .opacity(0.45)
                .allowsHitTesting(false)

                VStack(spacing: 10) {
                    Text("VIP")
                        .font(.system(size: 22, weight: .heavy, design: .monospaced))
                        .foregroundStyle(p.warn)
                    Text(store.t("signals.lockedCta"))
                        .font(IslandTheme.monoSmall)
                        .foregroundStyle(p.text)
                        .multilineTextAlignment(.center)
                    Button(store.vipBuyLabel) {
                        store.openProSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(store.proStore.isPurchasing)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(p.bg.opacity(0.72))
                .overlay(Rectangle().stroke(p.warn.opacity(0.45), lineWidth: 1))
            }
        }
    }

    private var deskHero: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            (tightOn ? p.warn : p.cool).opacity(0.18),
                            p.panel.opacity(0.95),
                            p.bgMid.opacity(0.9),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke((tightOn ? p.warn : p.cool).opacity(pulse && tightOn ? 0.75 : 0.35), lineWidth: 1.2)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    ZStack {
                        Circle()
                            .stroke((tightOn ? p.warn : p.cool).opacity(0.25), lineWidth: 3)
                            .frame(width: 44, height: 44)
                        Circle()
                            .trim(from: 0, to: CGFloat(min(1, heatAvg)))
                            .stroke(
                                tightOn ? p.warn : p.cool,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 44, height: 44)
                        Text(tightOn ? "VIP" : "STD")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(tightOn ? p.warn : p.cool)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(tightOn ? store.t("signals.heroVip") : store.t("signals.heroStd"))
                            .font(IslandTheme.monoTitle)
                            .foregroundStyle(p.text)
                        Text(store.t("signals.blurbShort"))
                            .font(IslandTheme.monoSmall)
                            .foregroundStyle(p.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 6) {
                    deskChip("▲ +\(fmt1(desk.pnlPumpPercent))%", p.gain)
                    deskChip("▼ \(fmt1(desk.pnlDropPercent))%", p.danger)
                    deskChip("FEE \(fmt0(desk.feeHigh))", p.warn)
                    deskChip("CD \(desk.cooldownMinutes)m", p.cool)
                }

                if store.isVIP {
                    Toggle(store.t("vip.deskToggle"), isOn: Binding(
                        get: { store.thresholds.vipDeskEnabled },
                        set: { store.setVIPDeskEnabled($0) }
                    ))
                    .font(IslandTheme.monoSmall)
                    .tint(p.warn)
                } else {
                    Text(store.t("signals.vipUpsell"))
                        .font(IslandTheme.monoSmall)
                        .foregroundStyle(p.warn)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
        }
    }

    private var heatStats: some View {
        HStack(spacing: 8) {
            statTile(
                label: store.t("signals.statHot"),
                value: hottest?.symbol ?? "—",
                detail: hottest.map { $0.changeText } ?? "—",
                color: hottest.map { p.pnlColor($0.change24hPercent) } ?? p.muted
            )
            statTile(
                label: store.t("signals.statHeat"),
                value: "\(Int(heatAvg * 100))%",
                detail: store.t("signals.statHeatDetail"),
                color: heatAvg >= 0.7 ? p.warn : p.cool
            )
            statTile(
                label: store.t("signals.statFire"),
                value: "\(firedCount)",
                detail: store.t("signals.statFireDetail"),
                color: firedCount > 0 ? p.danger : p.muted
            )
        }
    }

    private var heatGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(store.t("signals.boardTitle"))
                    .font(IslandTheme.monoBold)
                    .foregroundStyle(p.accent)
                Spacer()
                Text(store.t("signals.nearHelp"))
                    .font(IslandTheme.monoSmall)
                    .foregroundStyle(p.muted)
            }

            if rankedTicks.isEmpty {
                Text(store.t("panel.marketsEmpty"))
                    .font(IslandTheme.mono)
                    .foregroundStyle(p.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(p.panel.opacity(0.5))
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(rankedTicks.prefix(8)) { tick in
                        heatTile(tick)
                    }
                }
            }
        }
    }

    private var liveFeed: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.t("signals.liveTitle"))
                .font(IslandTheme.monoBold)
                .foregroundStyle(p.accent)

            if liveSignals.isEmpty {
                HStack(spacing: 10) {
                    Circle()
                        .fill(p.cool.opacity(0.85))
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulse ? 1.25 : 0.85)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.t("signals.calm"))
                            .font(IslandTheme.monoBold)
                            .foregroundStyle(p.text)
                        Text(store.snapshot.activeSignals.first(where: { $0.kind == .calm })?.detail ?? "—")
                            .font(IslandTheme.monoSmall)
                            .foregroundStyle(p.muted)
                    }
                    Spacer()
                }
                .padding(10)
                .background(p.panel.opacity(0.55))
                .overlay(Rectangle().stroke(p.strokeDim, lineWidth: 1))
            } else {
                ForEach(liveSignals) { signal in
                    HStack(alignment: .center, spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(liveColor(signal.kind).opacity(0.18))
                                .frame(width: 34, height: 34)
                            Text(liveGlyph(signal.kind))
                                .font(IslandTheme.monoBold)
                                .foregroundStyle(liveColor(signal.kind))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(signal.title.uppercased())
                                .font(IslandTheme.monoBold)
                                .foregroundStyle(p.text)
                            Text(signal.detail)
                                .font(IslandTheme.monoSmall)
                                .foregroundStyle(p.muted)
                        }
                        Spacer(minLength: 0)
                        Text("LIVE")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(p.bg)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(liveColor(signal.kind))
                    }
                    .padding(10)
                    .background(liveColor(signal.kind).opacity(0.08))
                    .overlay(Rectangle().stroke(liveColor(signal.kind).opacity(0.45), lineWidth: 1))
                }
            }
        }
    }

    private var pingHistory: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(store.t("signals.historyTitle"))
                    .font(IslandTheme.monoBold)
                    .foregroundStyle(p.accent)
                Spacer()
                if !store.signalPingHistory.isEmpty {
                    Button(store.t("signals.historyClear")) {
                        store.clearSignalPingHistory()
                    }
                    .buttonStyle(.plain)
                    .font(IslandTheme.monoSmall)
                    .foregroundStyle(p.muted)
                }
            }

            if store.signalPingHistory.isEmpty {
                Text(store.t("signals.historyEmpty"))
                    .font(IslandTheme.monoSmall)
                    .foregroundStyle(p.muted)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(p.panel.opacity(0.5))
            } else {
                ForEach(store.signalPingHistory.prefix(8)) { ping in
                    HStack(alignment: .top, spacing: 8) {
                        Text(ping.kind.uppercased().prefix(4))
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(p.warn)
                            .frame(width: 36, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ping.title.uppercased())
                                .font(IslandTheme.monoBold)
                                .foregroundStyle(p.text)
                            Text(ping.detail)
                                .font(IslandTheme.monoSmall)
                                .foregroundStyle(p.muted)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 0)
                        Text(ping.at, style: .time)
                            .font(IslandTheme.monoSmall)
                            .foregroundStyle(p.muted)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func actionStrip(for tick: AssetTick) -> some View {
        let prox = store.signalProximity(change24h: tick.change24hPercent)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(prox.side == "PUMP" ? "▲" : "▼")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(prox.side == "PUMP" ? p.gain : p.danger)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: store.t("signals.actionTitle"), tick.symbol, prox.side))
                        .font(IslandTheme.monoBold)
                        .foregroundStyle(p.text)
                    Text(store.t("signals.actionBody"))
                        .font(IslandTheme.monoSmall)
                        .foregroundStyle(p.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                Button(store.t("signals.openBinance")) {
                    store.openBinanceTrade(symbol: tick.symbol)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                Button(store.t("signals.openP2P")) {
                    store.openBinanceP2P()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button(store.t("signals.markSeen")) {
                    store.dismissActiveAlert()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [
                    (prox.side == "PUMP" ? p.gain : p.danger).opacity(0.2),
                    p.panel.opacity(0.9),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(
            Rectangle()
                .stroke((prox.side == "PUMP" ? p.gain : p.danger).opacity(0.55), lineWidth: 1)
        )
    }

    private func heatTile(_ tick: AssetTick) -> some View {
        let prox = store.signalProximity(change24h: tick.change24hPercent)
        let progress = min(1, max(0, prox.progress))
        let color: Color = {
            if prox.fired { return prox.side == "PUMP" ? p.gain : p.danger }
            if progress >= 0.7 { return p.warn }
            return p.cool
        }()

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(tick.symbol)
                    .font(IslandTheme.monoBold)
                    .foregroundStyle(p.text)
                Spacer()
                Text(prox.fired ? store.t("signals.fire") : "\(Int(progress * 100))%")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(color)
            }

            // Terminal proximity meter (CRT ops, not dashboard cards).
            GeometryReader { geo in
                let blocks = 12
                let lit = Int((progress * Double(blocks)).rounded(.down))
                HStack(spacing: 2) {
                    ForEach(0..<blocks, id: \.self) { i in
                        Rectangle()
                            .fill(i < lit ? color : p.strokeDim.opacity(0.45))
                            .frame(width: max(2, (geo.size.width - CGFloat(blocks - 1) * 2) / CGFloat(blocks)), height: 8)
                    }
                }
            }
            .frame(height: 8)

            HStack {
                Text(prox.side == "PUMP" ? "▲" : "▼")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                Text(tick.changeText)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(p.pnlColor(tick.change24hPercent))
                Spacer()
                Text(tick.priceText)
                    .font(IslandTheme.monoSmall)
                    .foregroundStyle(p.muted)
            }

            // Synthetic 24h spark from signed move (visual cue only).
            terminalSpark(change: tick.change24hPercent, color: color)
                .frame(height: 22)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(p.panel.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(color.opacity(prox.fired ? 0.7 : 0.28), lineWidth: prox.fired ? 1.4 : 1)
        )
        .onTapGesture {
            guard store.isVIP else { return }
            store.openBinanceTrade(symbol: tick.symbol)
        }
    }

    private func terminalSpark(change: Double, color: Color) -> some View {
        let points = sparkPoints(change: change)
        return GeometryReader { geo in
            Path { path in
                guard points.count > 1 else { return }
                let w = geo.size.width
                let h = geo.size.height
                for (i, y) in points.enumerated() {
                    let x = w * CGFloat(i) / CGFloat(points.count - 1)
                    let py = h * (1 - CGFloat(y))
                    if i == 0 { path.move(to: CGPoint(x: x, y: py)) }
                    else { path.addLine(to: CGPoint(x: x, y: py)) }
                }
            }
            .stroke(color.opacity(0.85), style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))
        }
    }

    /// Cheap visual spark derived from 24h % — not historical OHLC.
    private func sparkPoints(change: Double) -> [Double] {
        let end = min(1, max(0, 0.5 + change / 20))
        return (0..<8).map { i in
            let t = Double(i) / 7
            let wobble = sin(t * .pi * 2.2 + change) * 0.06
            return min(1, max(0, 0.5 + (end - 0.5) * t + wobble))
        }
    }

    private func statTile(label: String, value: String, detail: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(p.muted)
            Text(value)
                .font(IslandTheme.monoTitle)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(IslandTheme.monoSmall)
                .foregroundStyle(p.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(p.panel.opacity(0.65))
        .overlay(Rectangle().stroke(color.opacity(0.28), lineWidth: 1))
    }

    private func deskChip(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .overlay(Rectangle().stroke(color.opacity(0.4), lineWidth: 1))
    }

    private func liveGlyph(_ kind: MarketSignal.Kind) -> String {
        switch kind {
        case .calm: "·"
        case .dump: "▼"
        case .pump: "▲"
        case .feeHigh: "!"
        case .health: "♥"
        }
    }

    private func liveColor(_ kind: MarketSignal.Kind) -> Color {
        switch kind {
        case .calm: p.accent
        case .dump: p.danger
        case .pump: p.gain
        case .feeHigh: p.warn
        case .health: p.danger
        }
    }

    private func fmt1(_ value: Double) -> String { String(format: "%.1f", value) }
    private func fmt0(_ value: Double) -> String { String(format: "%.0f", value) }
}

/// Superadmin broker bot — suggests setups; never executes trades.
private struct RadarBrokerBotPage: View {
    @Bindable var store: AppStore
    private var p: ThemePalette { store.palette }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                botHero
                liveContext
                ForEach(store.brokerSuggestions) { tip in
                    suggestionCard(tip)
                }
            }
            .padding(12)
        }
    }

    private var botHero: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(store.t("bot.heroTitle"))
                    .font(IslandTheme.monoTitle)
                    .foregroundStyle(p.warn)
                Spacer()
                Text("SUGGEST ONLY")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(p.bg)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(p.warn)
            }
            Text(store.t("bot.heroBody"))
                .font(IslandTheme.monoSmall)
                .foregroundStyle(p.muted)
                .fixedSize(horizontal: false, vertical: true)
            Text(store.t("bot.heroRule"))
                .font(IslandTheme.monoSmall)
                .foregroundStyle(p.danger)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [p.warn.opacity(0.16), p.panel.opacity(0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(Rectangle().stroke(p.warn.opacity(0.45), lineWidth: 1))
    }

    private var liveContext: some View {
        let dumps = store.snapshot.activeSignals.filter { $0.kind == .dump }.count
        let pumps = store.snapshot.activeSignals.filter { $0.kind == .pump }.count
        return HStack(spacing: 8) {
            ctxChip("DUMP \(dumps)", dumps > 0 ? p.danger : p.muted)
            ctxChip("PUMP \(pumps)", pumps > 0 ? p.gain : p.muted)
            ctxChip("HEAT \(Int(store.deskHeatAvg * 100))%", store.deskHeatAvg >= 0.7 ? p.warn : p.cool)
            ctxChip(
                store.snapshot.openP2POrders.contains(where: \.isOpen) ? "P2P LIVE" : "NO P2P",
                store.snapshot.openP2POrders.contains(where: \.isOpen) ? p.warn : p.muted
            )
        }
    }

    private func suggestionCard(_ tip: BrokerBot.Suggestion) -> some View {
        let color = stanceColor(tip.stance)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(stanceLabel(tip.stance))
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(p.bg)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(color)
                if let sym = tip.symbol {
                    Text(sym)
                        .font(IslandTheme.monoBold)
                        .foregroundStyle(p.text)
                }
                Spacer()
                Text("\(tip.confidence)%")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(color)
            }
            Text(store.t(tip.titleKey))
                .font(IslandTheme.monoBold)
                .foregroundStyle(p.text)
            Text(formatBody(tip))
                .font(IslandTheme.monoSmall)
                .foregroundStyle(p.muted)
                .fixedSize(horizontal: false, vertical: true)

            if !tip.actions.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tip.actions, id: \.rawValue) { action in
                        Button(actionLabel(action)) {
                            store.runBrokerAction(action, suggestion: tip)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(action == .dismiss ? p.muted : color)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .overlay(Rectangle().stroke(color.opacity(0.4), lineWidth: 1))
    }

    private func stanceLabel(_ stance: BrokerBot.Stance) -> String {
        switch stance {
        case .hold: store.t("bot.stance.hold")
        case .watchLong: store.t("bot.stance.watchLong")
        case .watchShort: store.t("bot.stance.watchShort")
        case .standAside: store.t("bot.stance.standAside")
        case .ops: store.t("bot.stance.ops")
        case .fee: store.t("bot.stance.fee")
        }
    }

    private func stanceColor(_ stance: BrokerBot.Stance) -> Color {
        switch stance {
        case .hold: p.cool
        case .watchLong: p.gain
        case .watchShort: p.danger
        case .standAside: p.warn
        case .ops: p.accent
        case .fee: p.warn
        }
    }

    private func actionLabel(_ action: BrokerBot.Action) -> String {
        switch action {
        case .openTrade: store.t("signals.openBinance")
        case .openP2P: store.t("signals.openP2P")
        case .openEarn: store.t("signals.openEarn")
        case .openSignals: store.t("bot.action.signals")
        case .dismiss: store.t("bot.action.dismiss")
        }
    }

    private func formatBody(_ tip: BrokerBot.Suggestion) -> String {
        let template = store.t(tip.bodyKey)
        guard !tip.bodyArgs.isEmpty else { return template }
        var out = template
        for arg in tip.bodyArgs {
            if let range = out.range(of: "%d") {
                out.replaceSubrange(range, with: String(describing: arg))
            } else if let range = out.range(of: "%@") {
                out.replaceSubrange(range, with: String(describing: arg))
            } else {
                break
            }
        }
        return out
    }

    private func ctxChip(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .overlay(Rectangle().stroke(color.opacity(0.35), lineWidth: 1))
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
