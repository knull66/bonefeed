import AppKit
import Carbon.HIToolbox

/// ⌘⇧B toggles the Bonefeed panel from any app (local + global when permitted).
@MainActor
enum GlobalHotKey {
    private static var localMonitor: Any?
    private static var globalMonitor: Any?
    private static weak var store: AppStore?

    static func start(store: AppStore) {
        self.store = store
        stop()

        let handler: (NSEvent) -> NSEvent? = { event in
            // ⌘⇧B
            guard event.modifierFlags.contains([.command, .shift]),
                  event.keyCode == UInt16(kVK_ANSI_B)
            else { return event }
            store.togglePanel()
            return nil
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: handler)
        // Global requires Accessibility permission; fails silently if denied.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.contains([.command, .shift]),
                  event.keyCode == UInt16(kVK_ANSI_B)
            else { return }
            Task { @MainActor in
                store.togglePanel()
            }
        }
    }

    static func stop() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }
}
