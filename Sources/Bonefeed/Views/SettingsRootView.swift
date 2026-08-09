import AppKit
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable, Hashable {
    case general
    case pro
    case display
    case language
    case radar
    case binance
    case wallets
    case alerts
    case guide
    case privacy
    case about

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .general: "settings.pane.general"
        case .pro: "settings.pane.pro"
        case .display: "settings.pane.display"
        case .language: "settings.pane.language"
        case .radar: "settings.pane.radar"
        case .binance: "settings.pane.binance"
        case .wallets: "settings.pane.wallets"
        case .alerts: "settings.pane.alerts"
        case .guide: "settings.pane.guide"
        case .privacy: "settings.pane.privacy"
        case .about: "settings.pane.about"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .pro: "star.circle"
        case .display: "circle.lefthalf.filled"
        case .language: "globe"
        case .radar: "dot.radiowaves.left.and.right"
        case .binance: "key"
        case .wallets: "link"
        case .alerts: "bell"
        case .guide: "book"
        case .privacy: "hand.raised"
        case .about: "info.circle"
        }
    }

    var group: String {
        switch self {
        case .general, .pro, .display, .language, .radar, .binance, .wallets, .alerts: "Main"
        case .guide, .privacy, .about: Brand.name
        }
    }
}

struct SettingsRootView: View {
    @Bindable var store: AppStore
    @State private var pane: SettingsPane = .general

    private var p: ThemePalette { store.palette }

    var body: some View {
        NavigationSplitView {
            List(selection: $pane) {
                Section(store.t("settings.section.main")) {
                    ForEach(SettingsPane.allCases.filter { $0.group == "Main" }) { item in
                        Label(store.t(item.titleKey), systemImage: item.systemImage)
                            .tag(item)
                    }
                }
                Section(Brand.name) {
                    ForEach(SettingsPane.allCases.filter { $0.group == Brand.name }) { item in
                        Label(store.t(item.titleKey), systemImage: item.systemImage)
                            .tag(item)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 168, ideal: 184, max: 220)
        } detail: {
            Group {
                switch pane {
                case .general: GeneralSettingsPane(store: store)
                case .pro: ProSettingsPane(store: store)
                case .display: DisplaySettingsPane(store: store)
                case .language: LanguageSettingsPane(store: store)
                case .radar: RadarSettingsPane(store: store)
                case .binance: BinanceSettingsPane(store: store)
                case .wallets: WalletsSettingsPane(store: store)
                case .alerts: AlertsSettingsPane(store: store)
                case .guide: GuideSettingsPane(store: store)
                case .privacy: PrivacySettingsPane(store: store)
                case .about: AboutSettingsPane(store: store)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(22)
            .background(Color(nsColor: .windowBackgroundColor))
            .id(store.appLanguage) // force rebuild copy when language flips
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 640, minHeight: 480)
        .preferredColorScheme(store.appTheme.colorScheme)
        .environment(\.chainPalette, p)
        .onAppear {
            store.refreshLaunchAtLoginStatus()
            Task { await store.refreshNotificationStatus() }
        }
        .onChange(of: store.appLanguage) { _, _ in
            NSApp.keyWindow?.title = Brand.settingsTitle
        }
        .onChange(of: store.appTheme) { _, theme in
            NSApp.keyWindow?.appearance = NSAppearance(named: theme.isLight ? .aqua : .darkAqua)
        }
    }
}

// MARK: - Panes

private struct SettingsHeader: View {
    let pane: SettingsPane
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: pane.systemImage)
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .center)
            Text(title)
                .font(.title2.weight(.semibold))
            Spacer()
        }
        .padding(.bottom, 4)
    }
}

private struct GeneralSettingsPane: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsHeader(pane: .general, title: store.t("settings.pane.general"))

            GroupBox(store.t("general.system")) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(store.t("general.launchAtLogin"), isOn: Binding(
                        get: { store.launchAtLoginEnabled },
                        set: { store.setLaunchAtLogin($0) }
                    ))
                    Text(store.launchAtLoginStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if store.launchAtLoginStatusText.localizedCaseInsensitiveContains("Pendiente") || store.launchAtLoginStatusText.localizedCaseInsensitiveContains("Pending") {
                        Text(store.t("general.loginBlocked"))
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Button(store.t("general.openLoginItems")) {
                        store.openLoginItemsSettings()
                        store.refreshLaunchAtLoginStatus()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            GroupBox(store.t("general.runtime")) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(store.t("general.pause"), isOn: $store.isPaused)
                    Toggle(store.t("general.sound"), isOn: $store.soundEnabled)
                    Text(store.t("general.pollHint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct DisplaySettingsPane: View {
    @Bindable var store: AppStore
    private var p: ThemePalette { store.palette }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsHeader(pane: .display, title: store.t("settings.pane.display"))

                GroupBox(store.t("display.theme")) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(AppTheme.allCases) { theme in
                            let selected = store.appTheme == theme
                            Button {
                                store.selectTheme(theme)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selected ? p.cool : .secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(theme.title)
                                                .font(.body.weight(.semibold))
                                                .foregroundStyle(.primary)
                                            if theme.requiresPro {
                                                ProBadge()
                                            }
                                        }
                                        Text(theme.blurb)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    ThemeSwatch(theme: theme)
                                        .opacity(theme.requiresPro && !store.isPro ? 0.45 : 1)
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                }

                Text(store.t("display.themeHint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ThemeSwatch: View {
    let theme: AppTheme

    var body: some View {
        let p = ThemePalette.forTheme(theme)
        HStack(spacing: 3) {
            Circle().fill(p.accent).frame(width: 10, height: 10)
            Circle().fill(p.cool).frame(width: 10, height: 10)
            Circle().fill(p.warn).frame(width: 10, height: 10)
        }
        .padding(6)
        .background(p.bg, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct RadarSettingsPane: View {
    @Bindable var store: AppStore
    @State private var customSymbol = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsHeader(pane: .radar, title: store.t("settings.pane.radar"))

            GroupBox(store.t("radar.watchlist")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(store.t("radar.watchlistHint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                        ForEach(RadarWatchlist.presets, id: \.self) { symbol in
                            let on = store.watchedAssets.contains(symbol)
                            Button {
                                store.toggleWatchedAsset(symbol)
                            } label: {
                                Text(symbol)
                                    .font(.caption.weight(.semibold).monospaced())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(on ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .strokeBorder(on ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.1), lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        TextField(store.t("radar.custom"), text: $customSymbol)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 180)
                        Button(store.t("radar.add")) {
                            store.addWatchedAsset(customSymbol)
                            customSymbol = ""
                        }
                        .disabled(customSymbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if !store.watchedAssets.isEmpty {
                        Text(store.t("radar.active") + " " + store.watchedAssets.joined(separator: " · "))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Button(store.t("radar.reset")) {
                            store.resetWatchedAssets()
                        }
                        Text(store.t("radar.stablesNote"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            GroupBox(store.t("radar.onchain")) {
                Text(store.t("radar.onchainHint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct BinanceSettingsPane: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsHeader(pane: .binance, title: store.t("settings.pane.binance"))

            if !store.isPro {
                ProGateBanner(text: store.t("pro.gate.binance"), store: store)
            }

            GroupBox(store.t("binance.apiTitle")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(store.t("binance.apiHint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("API Key", text: $store.binanceAPIKeyDraft)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!store.isPro)
                    SecureField("API Secret", text: $store.binanceAPISecretDraft)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!store.isPro)

                    Text(store.binanceMessage)
                        .font(.caption)
                        .foregroundStyle(store.snapshot.binanceConnected ? .green : .orange)

                    HStack(spacing: 10) {
                        Button(store.t("binance.save")) { store.saveBinanceCredentials() }
                            .keyboardShortcut(.defaultAction)
                            .disabled(!store.isPro)
                        Button(store.t("binance.test")) {
                            Task { await store.testBinanceConnection() }
                        }
                        .disabled(!store.isPro)
                        Button(store.t("binance.clear"), role: .destructive) {
                            store.clearBinanceCredentials()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
                .opacity(store.isPro ? 1 : 0.55)
            }

            Text(store.t("binance.encrypted"))
                .font(.caption)
                .foregroundStyle(.secondary)

            if store.snapshot.userStreamLive {
                Text(store.t("binance.streamLive"))
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct WalletsSettingsPane: View {
    @Bindable var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsHeader(pane: .wallets, title: store.t("settings.pane.wallets"))

                if !store.isPro {
                    ProGateBanner(
                        text: store.t("pro.gate.walletsLimit")
                            .replacingOccurrences(of: "{n}", with: "\(ProLimits.freeWalletCap)"),
                        store: store
                    )
                }

                GroupBox(store.t("wallets.watch")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(store.t("wallets.hint"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker(store.t("wallets.chain"), selection: $store.draftChain) {
                            ForEach(ChainKind.allCases, id: \.self) { chain in
                                Text(chain == .eth ? "ETH / MetaMask" : chain.title).tag(chain)
                            }
                        }
                        .pickerStyle(.segmented)

                        if store.draftChain == .eth {
                            Text(store.t("wallets.metamaskTip"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button(store.t("wallets.metamaskLabel")) {
                                store.draftLabel = "MetaMask"
                            }
                            .buttonStyle(.borderless)
                        }

                        TextField(store.t("wallets.label"), text: $store.draftLabel)
                            .textFieldStyle(.roundedBorder)
                        TextField(addressPlaceholder(store.draftChain), text: $store.draftAddress)
                            .textFieldStyle(.roundedBorder)
                        Button(store.t("wallets.add")) { store.addDraftWallet() }

                        if store.watchedWallets.isEmpty {
                            Text(store.t("wallets.empty"))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(store.watchedWallets) { w in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(w.chain.title)
                                                .font(.caption2.weight(.bold).monospaced())
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.primary.opacity(0.08))
                                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                            Text(w.label)
                                                .font(.body.weight(.medium))
                                        }
                                        Text(w.address)
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.secondary)
                                            .textSelection(.enabled)
                                    }
                                    Spacer()
                                    Button(store.t("wallets.remove"), role: .destructive) {
                                        store.removeWallet(w)
                                    }
                                }
                                Divider()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                }
            }
        }
    }

    private func addressPlaceholder(_ chain: ChainKind) -> String {
        switch chain {
        case .btc: "bc1… / 1… / 3…"
        case .eth: "0x… (MetaMask)"
        case .sol: "Solana base58…"
        }
    }
}

private struct ProSettingsPane: View {
    @Bindable var store: AppStore
    private var p: ThemePalette { store.palette }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsHeader(pane: .pro, title: store.t("settings.pane.pro"))

                GroupBox {
                    HStack(spacing: 12) {
                        Image(systemName: store.isPro ? "checkmark.seal.fill" : "lock.fill")
                            .font(.title2)
                            .foregroundStyle(store.isPro ? p.cool : p.warn)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.isPro ? store.t("pro.status.pro") : store.t("pro.status.free"))
                                .font(.headline)
                            Text(store.isPro ? store.t("pro.status.proDetail") : store.t("pro.status.freeDetail"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(4)
                }

                GroupBox(store.t("pro.freeTitle")) {
                    VStack(alignment: .leading, spacing: 6) {
                        bullet(store.t("pro.free.1"))
                        bullet(store.t("pro.free.2"))
                        bullet(store.t("pro.free.3"))
                        bullet(store.t("pro.free.4"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                }

                GroupBox(store.t("pro.proTitle")) {
                    VStack(alignment: .leading, spacing: 6) {
                        bullet(store.t("pro.pro.1"))
                        bullet(store.t("pro.pro.2"))
                        bullet(store.t("pro.pro.3"))
                        bullet(store.t("pro.pro.4"))
                        bullet(store.t("pro.pro.5"))
                        bullet(store.t("pro.pro.6"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                }

                if store.isPro {
                    Text(store.t("pro.thanks"))
                        .font(.callout)
                        .foregroundStyle(p.cool)
                    if ProLimits.allowLocalUnlock {
                        Button(store.t("pro.lockTest")) {
                            store.lockProLocal()
                        }
                        .foregroundStyle(.secondary)
                    }
                } else {
                    Button {
                        Task { await store.purchasePro() }
                    } label: {
                        Text(store.proBuyLabel)
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(store.proStore.isPurchasing)

                    Button(store.t("pro.restore")) {
                        Task { await store.restorePro() }
                    }
                    .disabled(store.proStore.isRefreshing)

                    Text(store.t("pro.storeHint"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if ProLimits.allowLocalUnlock {
                        Button(store.t("pro.unlockDebug")) {
                            store.unlockProLocal()
                        }
                        .foregroundStyle(.secondary)
                        Text(store.t("pro.debugNote"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if !store.proMessage.isEmpty {
                    Text(store.proMessage)
                        .font(.caption)
                        .foregroundStyle(p.cool)
                }
            }
        }
        .onAppear {
            store.proStore.start()
            Task {
                await store.proStore.loadProduct()
                store.syncProStatus()
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.orange.opacity(0.85)))
    }
}

private struct ProGateBanner: View {
    let text: String
    @Bindable var store: AppStore

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "star.circle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(store.proBuyLabel) {
                    Task { await store.purchasePro() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(store.proStore.isPurchasing)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct AlertsSettingsPane: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsHeader(pane: .alerts, title: store.t("settings.pane.alerts"))

            GroupBox(store.t("alerts.notifications")) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(store.t("alerts.enable"), isOn: Binding(
                        get: { store.notificationsEnabled },
                        set: { on in
                            store.notificationsEnabled = on
                            if on { Task { await store.enableNotifications() } }
                        }
                    ))
                    Text(store.notificationStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button(store.t("alerts.request")) {
                            Task { await store.enableNotifications() }
                        }
                        Button(store.t("alerts.openSystem")) {
                            store.openNotificationSettings()
                        }
                        Button(store.t("alerts.test")) {
                            store.testNotification()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            GroupBox(store.t("alerts.signals")) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(store.t("alerts.pumpDump"), isOn: Binding(
                        get: { store.thresholds.pnlAlertsEnabled },
                        set: { store.setPnLAlertsEnabled($0) }
                    ))
                    if store.thresholds.pnlAlertsEnabled {
                        HStack {
                            Text(store.t("alerts.dump"))
                            Stepper(
                                value: Binding(
                                    get: { store.thresholds.pnlDropPercent },
                                    set: { store.updatePnLDrop($0) }
                                ),
                                in: -20...(-1),
                                step: 1
                            ) {
                                Text(String(format: "%.0f%%", store.thresholds.pnlDropPercent))
                                    .monospacedDigit()
                            }
                        }
                        HStack {
                            Text(store.t("alerts.pump"))
                            Stepper(
                                value: Binding(
                                    get: { store.thresholds.pnlPumpPercent },
                                    set: { store.updatePnLPump($0) }
                                ),
                                in: 1...20,
                                step: 1
                            ) {
                                Text(String(format: "+%.0f%%", store.thresholds.pnlPumpPercent))
                                    .monospacedDigit()
                            }
                        }
                        Text(store.t("alerts.signalAssets"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 6)], spacing: 6) {
                            ForEach(store.watchedAssets, id: \.self) { symbol in
                                let on = store.thresholds.signalAssets.isEmpty
                                    || store.thresholds.signalAssets.contains(symbol)
                                Button {
                                    store.toggleSignalAsset(symbol)
                                } label: {
                                    Text(symbol)
                                        .font(.caption2.weight(.semibold).monospaced())
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 5)
                                        .background(on ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if store.thresholds.signalAssets.isEmpty {
                            Text(store.t("alerts.filterOff"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle(store.t("alerts.fee"), isOn: Binding(
                        get: { store.thresholds.feeAlertsEnabled },
                        set: { store.setFeeAlertsEnabled($0) }
                    ))
                    if store.thresholds.feeAlertsEnabled {
                        HStack {
                            Text(store.t("alerts.feeAt"))
                            Stepper(
                                value: Binding(
                                    get: { store.thresholds.feeHigh },
                                    set: { store.updateFeeHigh($0) }
                                ),
                                in: 10...200,
                                step: 5
                            ) {
                                Text(String(format: "%.0f sat/vB", store.thresholds.feeHigh))
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            GroupBox(store.t("alerts.delivery")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(store.t("alerts.cooldown"))
                        Stepper(
                            value: Binding(
                                get: { store.thresholds.cooldownMinutes },
                                set: { store.updateCooldownMinutes($0) }
                            ),
                            in: 5...180,
                            step: 5
                        ) {
                            Text("\(store.thresholds.cooldownMinutes) min")
                                .monospacedDigit()
                        }
                    }
                    Toggle(store.t("alerts.quiet"), isOn: Binding(
                        get: { store.thresholds.quietHoursEnabled },
                        set: { store.updateQuietHours(enabled: $0) }
                    ))
                    if store.thresholds.quietHoursEnabled {
                        HStack {
                            Text(store.t("alerts.from"))
                            Stepper(
                                value: Binding(
                                    get: { store.thresholds.quietHoursStart },
                                    set: { store.updateQuietHours(start: $0) }
                                ),
                                in: 0...23
                            ) {
                                Text(String(format: "%02d:00", store.thresholds.quietHoursStart))
                                    .monospacedDigit()
                            }
                            Text(store.t("alerts.to"))
                            Stepper(
                                value: Binding(
                                    get: { store.thresholds.quietHoursEnd },
                                    set: { store.updateQuietHours(end: $0) }
                                ),
                                in: 0...23
                            ) {
                                Text(String(format: "%02d:00", store.thresholds.quietHoursEnd))
                                    .monospacedDigit()
                            }
                        }
                        Text(store.t("alerts.quietHint"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            GroupBox(store.t("alerts.aave")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(store.t("alerts.aaveHint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle(store.t("alerts.health"), isOn: Binding(
                        get: { store.thresholds.healthAlertsEnabled },
                        set: { store.setHealthAlertsEnabled($0) }
                    ))
                    if store.thresholds.healthAlertsEnabled {
                        HStack {
                            Text(store.t("alerts.healthWarn"))
                            Stepper(
                                value: Binding(
                                    get: { store.thresholds.healthFactorWarn },
                                    set: { store.updateHealthFactorWarn($0) }
                                ),
                                in: 1.05...3.0,
                                step: 0.05
                            ) {
                                Text(String(format: "%.2f", store.thresholds.healthFactorWarn))
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            GroupBox(store.t("alerts.p2p")) {
                VStack(alignment: .leading, spacing: 12) {
                    if !store.isPro {
                        ProGateBanner(text: store.t("pro.gate.binance"), store: store)
                    }
                    Text(store.t("alerts.p2pHint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle(store.t("alerts.p2pEnable"), isOn: Binding(
                        get: { store.thresholds.p2pAlertsEnabled },
                        set: { store.setP2PAlertsEnabled($0) }
                    ))
                    .disabled(!store.isPro)
                    if store.isPro, store.thresholds.p2pAlertsEnabled {
                        HStack {
                            Text(store.t("alerts.p2pFiat"))
                            Picker("", selection: Binding(
                                get: { P2PFiatOption.fromStored(store.thresholds.p2pFiat) },
                                set: { store.setP2PFiat($0.rawValue) }
                            )) {
                                ForEach(P2PFiatOption.allCases) { option in
                                    Text(option == .auto ? store.t("alerts.p2pFiatAuto") : option.label)
                                        .tag(option)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 160)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
                .opacity(store.isPro ? 1 : 0.55)
            }

            Spacer(minLength: 0)
        }
    }
}


private struct LanguageSettingsPane: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsHeader(pane: .language, title: store.t("settings.pane.language"))
            GroupBox(store.t("language.title")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(store.t("language.hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $store.appLanguage) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.menuLabel).tag(lang)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    Text(store.t("language.defaultNote"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct GuideSettingsPane: View {
    @Bindable var store: AppStore
    private var p: ThemePalette { store.palette }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsHeader(pane: .guide, title: store.t("settings.pane.guide"))
                Text(store.t("guide.blurb"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                GuideStepsView(store: store)
                    .environment(\.chainPalette, p)
                Button(store.t("guide.openPanel")) {
                    store.showGuideFromSettings()
                }
                .keyboardShortcut(.defaultAction)
                Text(store.t("guide.footnote"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct PrivacySettingsPane: View {
    @Bindable var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsHeader(pane: .privacy, title: store.t("settings.pane.privacy"))
                GroupBox(store.t("privacy.termsTitle")) {
                    Text(store.t("privacy.termsBody"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                        .textSelection(.enabled)
                }
                GroupBox(store.t("privacy.privacyTitle")) {
                    Text(store.t("privacy.privacyBody"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                        .textSelection(.enabled)
                }
                Text(store.t("privacy.ack"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AboutSettingsPane: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsHeader(pane: .about, title: store.t("settings.pane.about"))

            HStack(spacing: 16) {
                AppLogoView()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(Brand.name)
                        .font(.title3.weight(.semibold))
                    Text("v1.0.0 · \(Brand.tagline)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent(store.t("about.mode"), value: store.t("about.modeValue"))
                    LabeledContent(store.t("about.chains"), value: store.t("about.chainsValue"))
                    LabeledContent(store.t("about.data"), value: store.t("about.dataValue"))
                    LabeledContent(store.t("about.secrets"), value: store.t("about.secretsValue"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            Button(store.t("about.showGuide")) {
                store.showGuideFromSettings()
            }

            if let site = Brand.siteURL {
                Link(destination: site) {
                    Label(Brand.siteHost, systemImage: "globe")
                        .font(.caption.weight(.semibold))
                }
            }

            Text(store.t("about.footer"))
                .font(.caption)
                .foregroundStyle(.secondary)

            StudioCreditRow()

            Spacer(minLength: 0)
        }
    }
}

private struct StudioCreditRow: View {
    var body: some View {
        Group {
            if let url = Brand.studioURL {
                Link(destination: url) {
                    creditContent
                }
                .buttonStyle(.plain)
            } else {
                creditContent
            }
        }
        .padding(.top, 8)
    }

    private var creditContent: some View {
        HStack(spacing: 8) {
            if let image = StudioLogoImage.load() {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .opacity(0.75)
            }
            Text("\(L10n.t("about.madeBy")) \(Brand.studioName)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct AppLogoView: View {
    var body: some View {
        if let image = AppLogoImage.load() {
            Image(nsImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
        } else {
            Image(systemName: "circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
        }
    }
}
