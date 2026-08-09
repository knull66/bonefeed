import AppKit
import SwiftUI

@main
struct BonefeedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Backup menu (notch is the primary UI). Keep style `.menu` — not anchored window.
        MenuBarExtra {
            Button(appDelegate.store.isPanelOpen ? "Hide Panel" : "Show Panel") {
                appDelegate.store.togglePanel()
            }
            Button(appDelegate.store.isPanelPinned ? "Unpin Panel" : "Pin Panel") {
                appDelegate.store.togglePanelPin()
            }
            Divider()
            Button("Settings…") {
                appDelegate.store.openAppSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
            Divider()
            Button(Brand.quitTitle) {
                appDelegate.store.quitApp()
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
