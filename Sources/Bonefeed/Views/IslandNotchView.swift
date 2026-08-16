import SwiftUI

/// Menu-bar notch — liquid Dynamic-Island morph on hover (not a growing window).
struct IslandNotchView: View {
    @Bindable var store: AppStore
    private var p: ThemePalette { store.palette }
    private var isLight: Bool { store.appTheme.isLight }

    @State private var hovering = false
    @State private var collapseTask: Task<Void, Never>?
    @State private var morph: CGFloat = 0 // 0 collapsed → 1 expanded
    @State private var glitching = false
    @State private var glitchTask: Task<Void, Never>?

    /// Alert expand is store-driven (`alertNotchExpanded`); hover is local.
    /// Open P2P orders keep a slim timer dock after the alert collapses.
    private var hasLiveP2P: Bool { store.snapshot.openP2POrders.first != nil }
    private var wantsFullExpand: Bool { hovering || store.alertNotchExpanded }
    private var showingAlertPeek: Bool { store.alertNotchExpanded && store.bannerAlert != nil }
    private var showingP2PDock: Bool { hasLiveP2P && !wantsFullExpand }
    private var expanded: Bool { wantsFullExpand }

    private let spring = Animation.spring(response: 0.44, dampingFraction: 0.78, blendDuration: 0.12)

    var body: some View {
        GeometryReader { geo in
            let m = morph
            let compactH = max(store.notchMenuBarHeight, 25)
            let dockH = compactH + 40
            let expandH: CGFloat = hasLiveP2P ? 168 : (showingAlertPeek ? 132 : 150)
            let h: CGFloat = {
                if wantsFullExpand { return compactH + (expandH - compactH) * m }
                if showingP2PDock { return dockH }
                return compactH
            }()
            let compactW = min(geo.size.width - 16, 280)
            let expandW = min(max(geo.size.width - 10, 280), 328)
            let w = showingP2PDock && !wantsFullExpand
                ? min(max(geo.size.width - 12, 240), 300)
                : compactW + (expandW - compactW) * m
            let radius = compactH * 0.5 + (22 - compactH * 0.5) * (wantsFullExpand ? m : (showingP2PDock ? 0.35 : 0))

            islandChrome(width: w, height: h, radius: radius, compactH: compactH)
                .frame(width: geo.size.width, height: max(geo.size.height, h), alignment: .top)
        }
        .onTapGesture {
            if hasLiveP2P {
                store.openP2PStatus()
            } else if showingAlertPeek, let banner = store.bannerAlert {
                if banner.kind == .pnl || banner.kind == .gas {
                    store.openSignalsDesk()
                } else {
                    store.selectedTab = .log
                    if !store.isPanelOpen { store.togglePanel() }
                }
            } else if store.isVIP, store.deskHasFire {
                store.openSignalsDesk()
            } else {
                store.togglePanel()
            }
        }
        .onHover { handleHover($0) }
        .onChange(of: store.isPanelOpen) { _, open in
            if open {
                hovering = false
                store.notchPointerInside = false
            }
            store.syncNotchMode(hovering: hovering)
        }
        .onChange(of: wantsFullExpand) { _, on in
            withAnimation(spring) {
                morph = on ? 1 : 0
            }
            store.syncNotchMode(hovering: hovering)
            if on {
                startGlitchBurst()
            } else {
                stopGlitchBurst()
            }
        }
        .onChange(of: hasLiveP2P) { _, _ in
            store.syncNotchMode(hovering: hovering)
        }
        .task(id: store.alertNotchExpanded) {
            guard store.alertNotchExpanded else { return }
            withAnimation(spring) { morph = 1 }
            startGlitchBurst()
        }
        .environment(\.chainPalette, p)
        .help(notchHelpText)
    }

    private var notchHelpText: String {
        if hasLiveP2P { return store.t("notch.p2pDockHint") }
        if showingAlertPeek, let banner = store.bannerAlert, banner.kind == .pnl || banner.kind == .gas {
            return store.t("notch.alertSignalsHint")
        }
        if store.isPanelOpen { return store.t("notch.closePanel") }
        return store.t("notch.openPanel")
    }

    // MARK: - Morphing island

    private func islandChrome(width: CGFloat, height: CGFloat, radius: CGFloat, compactH: CGFloat) -> some View {
        // Collapsed: header fills the whole bar so content can true-center.
        // Expanded: compact header strip at the top.
        let expandedHeaderH: CGFloat = 22
        let headerH = compactH + (expandedHeaderH - compactH) * morph

        return VStack(spacing: 0) {
            headerStrip
                .frame(width: width - 24, height: headerH)

            if showingP2PDock, let order = store.snapshot.openP2POrders.first {
                p2pTimerTab(order)
                    .padding(.top, 4)
                    .padding(.bottom, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Group {
                    if showingAlertPeek, let banner = store.bannerAlert, banner.kind != .p2p {
                        alertPeekCard(banner)
                    } else if let order = store.snapshot.openP2POrders.first,
                              (store.bannerAlert?.kind == .p2p || showingAlertPeek || morph > 0.15) {
                        P2POrderStatusCard(order: order, compact: true)
                    } else if showingAlertPeek, let banner = store.bannerAlert {
                        alertPeekCard(banner)
                    } else {
                        peekCard
                    }
                }
                .padding(.top, 8 * morph)
                .padding(.bottom, 2 * morph)
                .frame(maxHeight: morph > 0.02 ? .infinity : 0)
                .opacity(Double(max(0, morph - 0.12) / 0.88))
                .allowsHitTesting(expanded)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 5 * morph)
        .frame(width: width, height: height, alignment: .top)
        .background { islandFill(radius: radius) }
        .overlay { islandStroke(radius: radius) }
        .overlay(alignment: .top) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isLight ? 0.28 : 0.16),
                            Color.white.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width * 0.38, height: 2)
                .offset(y: 3)
                .opacity(0.5 + 0.3 * morph)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        // Tight rim light — not a big halo.
        .shadow(color: Color.black.opacity(0.55 * morph), radius: 3, y: 2)
        .shadow(color: p.accent.opacity(0.22 * morph), radius: 5, y: 1)
        .brightness(store.pillPulse && morph < 0.5 ? 0.04 : 0)
    }

    @ViewBuilder
    private func islandFill(radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        p.bg.opacity(isLight ? 0.94 : 0.96),
                        p.bgMid.opacity(isLight ? 0.90 : 0.94)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(isLight ? 0.35 : 0.22))
            )
    }

    private func islandStroke(radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(
                AngularGradient(
                    colors: [
                        p.accent.opacity(0.55 + 0.25 * morph),
                        p.cool.opacity(0.25 + 0.35 * morph),
                        p.accent.opacity(0.15),
                        p.cool.opacity(0.40 + 0.20 * morph),
                        p.accent.opacity(0.55 + 0.25 * morph)
                    ],
                    center: .center
                ),
                lineWidth: 1 + 0.4 * morph
            )
            .opacity(0.85)
    }

    /// Persistent Binance-style timer strip — stays while the order is open.
    private func p2pTimerTab(_ order: BinanceP2POrder) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = order.remainingSeconds(at: context.date)
            HStack(spacing: 8) {
                Text(store.t("tab.p2p"))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(p.warn)
                Text(order.tradeType)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(order.tradeType == "SELL" ? p.danger : p.cool)
                Text(order.amountText)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(p.text)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let remaining, order.isOpen {
                    HStack(spacing: 3) {
                        Image(systemName: "stopwatch.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text(formatDockCountdown(remaining))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(remaining <= 60 ? p.danger : p.warn)
                } else {
                    Text(order.phase.shortLabel)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(p.cool)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(p.panel.opacity(0.95))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(p.warn.opacity(0.45), lineWidth: 1)
            )
        }
    }

    private func formatDockCountdown(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: - Header

    private var headerStrip: some View {
        HStack(alignment: .center, spacing: 7) {
            logo

            if store.isVIP {
                vipHeatBadge
            }

            // Keep the normal ticker in the header — alert detail lives in the peek below.
            NotchMarqueeView(items: NotchTickerItem.build(from: store), palette: p)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            if store.unreadAlertCount > 0 {
                Text("\(store.unreadAlertCount)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(isLight ? .white : p.bg)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(p.danger))
            } else if store.isPanelPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(p.warn.opacity(0.9))
            } else {
                Image(systemName: "chevron.compact.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(p.muted.opacity(0.55 + 0.35 * (1 - morph)))
                    .rotationEffect(.degrees(180 * morph))
                    .opacity(0.4 + 0.6 * (1 - morph * 0.5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var vipHeatBadge: some View {
        let heat = store.deskHeatAvg
        let hot = store.deskHasFire || heat >= 0.7
        let ring = hot ? p.warn : p.cool
        return ZStack {
            Circle()
                .fill(ring.opacity(hot ? 0.18 : 0.06))
                .frame(width: 18, height: 18)
                .scaleEffect(hot && store.pillPulse ? 1.15 : 1.0)
            Circle()
                .stroke(ring.opacity(0.28), lineWidth: 1.5)
                .frame(width: 16, height: 16)
            Circle()
                .trim(from: 0, to: CGFloat(min(1, max(0.08, heat))))
                .stroke(ring, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 16, height: 16)
            Text("V")
                .font(.system(size: 7, weight: .heavy, design: .monospaced))
                .foregroundStyle(ring)
        }
        .accessibilityLabel("VIP")
        .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: store.pillPulse && hot)
    }

    // MARK: - Peek

    private var peekCard: some View {
        let ticks = Array(store.snapshot.marketTicks.prefix(3))
        let snap = store.snapshot
        var rows: [(id: String, label: String, value: String, detail: String, up: Bool)] = []

        if store.isPro, snap.binanceConnected, snap.binancePortfolioUSD > 0 {
            let detail: String = {
                if let pnl = snap.portfolioPnL24hPercent {
                    return String(format: "%+.1f%%", pnl)
                }
                return snap.radarLabel
            }()
            rows.append((
                "port",
                "PORT",
                snap.binancePortfolioUSD.asUSDShort,
                detail,
                (snap.portfolioPnL24hPercent ?? 0) >= 0
            ))
        }

        if ticks.isEmpty, snap.btcPriceUSD > 0 {
            rows.append((
                "btc",
                "BTC",
                snap.btcPriceUSD.asPriceShort,
                String(format: "%+.1f%%", snap.marketChange24hPercent),
                snap.marketChange24hPercent >= 0
            ))
        } else {
            for tick in ticks {
                rows.append((
                    tick.id,
                    tick.symbol,
                    tick.priceText,
                    tick.changeText,
                    tick.change24hPercent >= 0
                ))
            }
        }

        if let open = snap.openP2POrders.first {
            rows.append((
                "p2p",
                "P2P",
                "\(open.tradeType) \(open.amountText)",
                open.phase.shortLabel,
                open.phase != .appeal && open.phase != .cancelled
            ))
        }

        if let alert = store.bannerAlert ?? store.alertLog.first {
            rows.append(("alert", "ALRT", String(alert.title.prefix(18)), "·", false))
        } else if snap.fee.rate > 0 {
            rows.append((
                "fee",
                "FEE",
                String(format: "%.0f sat", snap.fee.rate),
                snap.fee.level.rawValue.uppercased(),
                snap.fee.level != .high
            ))
        }

        return VStack(alignment: .leading, spacing: 6) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            p.accent.opacity(0),
                            p.accent.opacity(0.45),
                            p.cool.opacity(0.35),
                            p.accent.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .padding(.bottom, 2)
                .opacity(Double(morph))

            TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !glitching)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        glitchRow(
                            index: index,
                            time: t,
                            label: row.label,
                            value: row.value,
                            detail: row.detail,
                            up: row.up
                        )
                    }
                }
            }

            Text(store.t("notch.peekHint"))
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(p.muted.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 3)
                .opacity(Double(max(0, morph - 0.45) / 0.55))
        }
        .padding(.horizontal, 2)
        .clipped()
    }

    /// Hard RGB split + slice jitter — driven by a short burst, not a soft morph fade.
    private func glitchRow(
        index: Int,
        time: TimeInterval,
        label: String,
        value: String,
        detail: String,
        up: Bool
    ) -> some View {
        let gate = rowGate(for: index)
        let burst = glitching ? 1.0 : max(0, 1 - gate) * 0.35
        let flicker = abs(sin(time * 38 + Double(index) * 2.7))
        let g = CGFloat(burst) * CGFloat(0.55 + 0.45 * flicker)
        let jitter = CGFloat(sin(time * 55 + Double(index) * 11)) * 7 * g
        let slice = CGFloat(cos(time * 47 + Double(index) * 5)) * 4 * g
        // Always neon channels so it reads even on BLVCK.
        let cyan = Color(red: 0.0, green: 0.95, blue: 1.0)
        let mag = Color(red: 1.0, green: 0.15, blue: 0.55)

        return ZStack {
            if g > 0.05 {
                peekRow(label: label, value: value, detail: detail, up: up)
                    .foregroundStyle(cyan)
                    .offset(x: -3.5 * g + slice, y: slice * 0.3)
                    .opacity(0.75 * Double(g))
                    .blendMode(.screen)
                peekRow(label: label, value: value, detail: detail, up: up)
                    .foregroundStyle(mag)
                    .offset(x: 3.5 * g - slice, y: -slice * 0.25)
                    .opacity(0.75 * Double(g))
                    .blendMode(.screen)
            }
            peekRow(label: label, value: value, detail: detail, up: up)
                .offset(x: jitter * 0.6)
                .opacity(gate < 0.08 ? 0 : (0.55 + 0.45 * Double(gate)))
        }
        .clipShape(Rectangle())
        .overlay(alignment: .top) {
            if g > 0.2 {
                Rectangle()
                    .fill(cyan.opacity(0.35 * Double(g) * flicker))
                    .frame(height: 1)
                    .offset(y: CGFloat((index % 3) * 4) + slice)
                    .allowsHitTesting(false)
            }
        }
        .opacity(gate > 0.02 ? 1 : 0)
        .offset(x: (1 - gate) * 10)
    }

    /// Staggered 0…1 unlock per row as morph opens.
    private func rowGate(for index: Int) -> CGFloat {
        let start = 0.12 + CGFloat(index) * 0.07
        let span: CGFloat = 0.22
        return min(1, max(0, (morph - start) / span))
    }

    private func peekRow(label: String, value: String, detail: String, up: Bool) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(p.muted)
                .frame(width: 40, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(p.text)
            Spacer(minLength: 4)
            Text(detail)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(up ? p.gain : p.danger)
        }
    }

    // MARK: - Bits

    @ViewBuilder
    private var logo: some View {
        Group {
            if let logo = AppLogoImage.load() {
                Image(nsImage: logo)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            } else {
                Circle()
                    .fill(p.accent)
                    .frame(width: 7, height: 7)
            }
        }
        .opacity(store.pillPulse ? 1 : 0.95)
    }

    private func alertPeekCard(_ alert: IslandAlert) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            p.danger.opacity(0),
                            p.danger.opacity(0.55),
                            p.accent.opacity(0.35),
                            p.danger.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .padding(.bottom, 2)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: alert.kind.symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(alertAccent(alert.kind))
                    .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(alert.title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(p.text)
                        .lineLimit(1)
                    Text(alert.detail)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(p.muted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            if alert.kind == .pnl || alert.kind == .gas {
                HStack(spacing: 6) {
                    Button(store.t("signals.openBinance")) {
                        store.openBinanceTrade()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(p.cool)
                    Text("·")
                        .foregroundStyle(p.muted)
                    Button(store.t("signals.markSeen")) {
                        store.dismissActiveAlert()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(p.muted)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            Text(
                alert.kind == .pnl || alert.kind == .gas
                    ? store.t("notch.alertSignalsHint")
                    : store.t("notch.alertHint")
            )
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(p.muted.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
        }
        .padding(.horizontal, 2)
        .clipped()
    }

    private func alertAccent(_ kind: IslandAlert.Kind) -> Color {
        switch kind {
        case .deposit, .p2p: p.cool
        case .health, .gas: p.danger
        case .earn: p.accent
        case .pnl: p.warn
        case .whale: p.muted
        }
    }

    private func handleHover(_ inside: Bool) {
        if inside {
            collapseTask?.cancel()
            collapseTask = nil
            hovering = !store.isPanelOpen
            store.notchPointerInside = hovering
            store.syncNotchMode(hovering: hovering)
        } else {
            collapseTask?.cancel()
            collapseTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                hovering = false
                store.notchPointerInside = false
                store.syncNotchMode(hovering: false)
            }
        }
    }

    private func startGlitchBurst() {
        glitchTask?.cancel()
        glitching = true
        glitchTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(520))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.12)) {
                glitching = false
            }
        }
    }

    private func stopGlitchBurst() {
        glitchTask?.cancel()
        glitchTask = nil
        glitching = false
    }
}

// MARK: - Continuous horizontal marquee

private struct NotchMarqueeView: View {
    let items: [NotchTickerItem]
    let palette: ThemePalette

    private let speed: CGFloat = 34
    private let gap: CGFloat = 16

    @State private var loopWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let viewport = max(geo.size.width, 1)
            let loop = max(loopWidth, viewport + 24)

            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: items.count <= 1)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let travel = CGFloat(t) * speed
                let x = items.count <= 1 ? 0 : -(travel.truncatingRemainder(dividingBy: loop))

                HStack(spacing: gap) {
                    strip
                    if items.count > 1 { strip }
                }
                .offset(x: x)
            }
            .frame(width: viewport, height: geo.size.height, alignment: .center)
            .mask(edgeFadeMask)
            .background(alignment: .leading) {
                strip
                    .fixedSize()
                    .hidden()
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .onAppear { loopWidth = proxy.size.width + gap }
                                .onChange(of: items) { _, _ in
                                    loopWidth = proxy.size.width + gap
                                }
                        }
                    )
            }
        }
    }

    private var strip: some View {
        HStack(spacing: gap) {
            ForEach(items) { item in
                HStack(spacing: 4) {
                    Text(item.symbol)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.text.opacity(0.92))
                    Text(item.price)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.text.opacity(0.78))
                    Text(item.change)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(item.up ? palette.gain : palette.danger)
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var edgeFadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.08),
                .init(color: .black, location: 0.92),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Ticker items

private struct NotchTickerItem: Identifiable, Equatable {
    let id: String
    let symbol: String
    let price: String
    let change: String
    let up: Bool

    @MainActor
    static func build(from store: AppStore) -> [NotchTickerItem] {
        var items: [NotchTickerItem] = []
        let snap = store.snapshot

        if snap.binanceConnected, snap.binancePortfolioUSD > 0 {
            let change: String = {
                if let pnl = snap.portfolioPnL24hPercent {
                    return String(format: "%+.1f%%", pnl)
                }
                return "·"
            }()
            items.append(
                NotchTickerItem(
                    id: "port",
                    symbol: "PORT",
                    price: snap.binancePortfolioUSD.asUSDShort,
                    change: change,
                    up: (snap.portfolioPnL24hPercent ?? 0) >= 0
                )
            )
        }

        if !snap.marketTicks.isEmpty {
            for tick in snap.marketTicks.prefix(10) {
                items.append(
                    NotchTickerItem(
                        id: "m-\(tick.symbol)",
                        symbol: tick.symbol,
                        price: tick.priceText,
                        change: tick.changeText,
                        up: tick.change24hPercent >= 0
                    )
                )
            }
        } else if snap.btcPriceUSD > 0 {
            items.append(
                NotchTickerItem(
                    id: "btc",
                    symbol: "BTC",
                    price: snap.btcPriceUSD.asPriceShort,
                    change: String(format: "%+.1f%%", snap.marketChange24hPercent),
                    up: snap.marketChange24hPercent >= 0
                )
            )
        }

        if snap.fee.rate > 0 {
            items.append(
                NotchTickerItem(
                    id: "fee",
                    symbol: "FEE",
                    price: String(format: "%.0f", snap.fee.rate),
                    change: "sat",
                    up: snap.fee.level != .high
                )
            )
        }

        if items.isEmpty {
            items.append(
                NotchTickerItem(
                    id: "boot",
                    symbol: Brand.nameUpper,
                    price: "…",
                    change: snap.radarLabel,
                    up: true
                )
            )
        }

        return items
    }
}

private extension Double {
    var asUSDShort: String {
        abs(self) >= 1000
            ? String(format: "$%.1fk", self / 1000)
            : String(format: "$%.0f", self)
    }

    var asPriceShort: String {
        abs(self) >= 1000
            ? String(format: "$%.0f", self)
            : String(format: "$%.2f", self)
    }
}
