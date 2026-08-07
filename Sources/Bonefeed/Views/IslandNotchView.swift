import SwiftUI

/// Modern menu-bar notch — horizontal market ticker (CoinNotch-style), soft chrome.
struct IslandNotchView: View {
    @Bindable var store: AppStore
    private var p: ThemePalette { store.palette }
    private var isLight: Bool { store.appTheme.isLight }

    var body: some View {
        Button {
            store.togglePanel()
        } label: {
            HStack(spacing: 7) {
                logo

                Group {
                    if store.pillPulse, let banner = store.bannerAlert {
                        alertChip(banner.title)
                    } else {
                        NotchMarqueeView(items: NotchTickerItem.build(from: store), palette: p)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 16)
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
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(notchBackground)
            .clipShape(Capsule(style: .continuous))
            .scaleEffect(store.pillPulse ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: store.pillPulse)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .environment(\.chainPalette, p)
        .help(store.isPanelOpen ? "Close panel" : "Open \(Brand.name)")
    }

    @ViewBuilder
    private var notchBackground: some View {
        Capsule(style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                Capsule(style: .continuous)
                    .fill(p.bg.opacity(isLight ? 0.55 : (store.pillPulse ? 0.50 : 0.78)))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                p.accent.opacity(isLight ? 0.35 : 0.45),
                                p.cool.opacity(isLight ? 0.20 : 0.30)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 0.8
                    )
            )
    }

    @ViewBuilder
    private var logo: some View {
        Group {
            if let logo = AppLogoImage.load() {
                Image(nsImage: logo)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 13, height: 13)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            } else {
                Circle()
                    .fill(p.accent)
                    .frame(width: 7, height: 7)
            }
        }
        .opacity(store.pillPulse ? 1 : 0.95)
    }

    private func alertChip(_ title: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(p.danger)
                .frame(width: 5, height: 5)
            Text(String(title.prefix(22)))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(p.danger)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Continuous horizontal marquee

private struct NotchMarqueeView: View {
    let items: [NotchTickerItem]
    let palette: ThemePalette

    private let speed: CGFloat = 34 // points / second
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
                        .foregroundStyle(item.up ? palette.cool : palette.danger)
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

        // Lead with portfolio glance when connected.
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
