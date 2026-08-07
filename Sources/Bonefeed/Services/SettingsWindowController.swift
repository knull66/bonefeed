import AppKit
import SwiftUI

/// Dedicated settings window for LSUIElement / MenuBarExtra apps.
/// SwiftUI `Settings { }` + `showSettingsWindow:` often fails silently without a Dock activation context.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private weak var store: AppStore?

    func show(store: AppStore) {
        self.store = store

        // Temporarily appear as a normal app so the window can key + Dock can host it.
        NSApp.setActivationPolicy(.regular)

        if window == nil {
            let hosting = NSHostingController(rootView: SettingsRootView(store: store))
            let win = NSWindow(contentViewController: hosting)
            win.title = Brand.settingsTitle
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            win.titlebarAppearsTransparent = false
            win.isReleasedWhenClosed = false
            win.appearance = NSAppearance(named: store.appTheme.isLight ? .aqua : .darkAqua)
            win.delegate = self
            win.setContentSize(NSSize(width: 720, height: 520))
            win.minSize = NSSize(width: 640, height: 440)
            win.center()
            window = win
        }

        guard let window else { return }
        window.title = Brand.settingsTitle
        window.appearance = NSAppearance(named: store.appTheme.isLight ? .aqua : .darkAqua)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.performClose(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Back to menu-bar-only once settings is dismissed.
        DispatchQueue.main.async {
            if self.window?.isVisible != true {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}
