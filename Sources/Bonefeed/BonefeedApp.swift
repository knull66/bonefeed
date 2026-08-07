import SwiftUI

@main
struct BonefeedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Backup menu (notch is the primary UI). Keep style `.menu` — not anchored window.
        MenuBarExtra(Brand.name, systemImage: "circle.grid.cross.fill") {
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
        }
        .menuBarExtraStyle(.menu)
    }
}
