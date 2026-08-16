import AppKit
import SwiftUI

@main
struct BonefeedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Backup menu (notch is the primary UI). Keep style `.menu` — not anchored window.
        MenuBarExtra {
            let store = appDelegate.store
            Section(store.t("menu.section.panel")) {
                Button(store.isPanelOpen ? store.t("menu.hidePanel") : store.t("menu.showPanel")) {
                    store.togglePanel()
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])
                Button(store.isPanelPinned ? store.t("panel.unpin") : store.t("panel.pin")) {
                    store.togglePanelPin()
                }
            }
            Section(store.t("menu.section.radar")) {
                Button(store.t("menu.openOverview")) {
                    store.selectedTab = .radar
                    store.selectedRadarSubTab = .overview
                    if !store.isPanelOpen { store.togglePanel() }
                }
                Button(store.t("menu.openP2P")) {
                    store.openP2PStatus()
                }
                Button(store.t("menu.openSignals")) {
                    store.openSignalsDesk()
                }
                if store.superadminLabEnabled {
                    Button(store.t("menu.openBot")) {
                        store.openLabDesk()
                    }
                }
            }
            Section(store.t("menu.section.quick")) {
                Button(store.t("signals.openBinance")) {
                    store.openBinanceTrade()
                }
                Button(store.t("signals.openP2P")) {
                    store.openBinanceP2P()
                }
                Button(store.t("signals.openEarn")) {
                    store.openBinanceEarn()
                }
            }
            Divider()
            Button(store.t("menu.settings")) {
                store.openAppSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
            Button(Brand.quitTitle) {
                store.quitApp()
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            MenuBarLogoLabel()
        }
        .menuBarExtraStyle(.menu)
    }
}

/// White skull for the macOS menu bar (replaces `circle.grid.cross.fill`).
private struct MenuBarLogoLabel: View {
    /// Match typical menu-bar SF Symbol optical size (~18–22pt).
    private static let pointSize: CGFloat = 24

    var body: some View {
        if let image = Self.templateLogo() {
            Image(nsImage: image)
                .resizable()
                .interpolation(.none)
                .frame(width: Self.pointSize, height: Self.pointSize)
        } else {
            Image(systemName: "circle.grid.cross.fill")
                .font(.system(size: 16, weight: .medium))
        }
    }

    @MainActor
    private static func templateLogo() -> NSImage? {
        let names = ["AppIconWhite", "AppIcon"]
        for name in names {
            if let url = Bundle.main.url(forResource: name, withExtension: "png"),
               let img = NSImage(contentsOf: url) {
                let copy = img.copy() as? NSImage ?? img
                copy.isTemplate = true
                copy.size = NSSize(width: pointSize, height: pointSize)
                return copy
            }
        }
        if let img = AppLogoImage.load() {
            let copy = img.copy() as? NSImage ?? img
            copy.isTemplate = true
            copy.size = NSSize(width: pointSize, height: pointSize)
            return copy
        }
        return nil
    }
}
