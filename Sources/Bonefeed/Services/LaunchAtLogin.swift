import AppKit
import Foundation
import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var statusText: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            L10n.t("login.enabled")
        case .notRegistered:
            L10n.t("login.disabled")
        case .requiresApproval:
            L10n.t("login.pending")
        case .notFound:
            L10n.t("login.notFound")
        @unknown default:
            "—"
        }
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> String {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return statusText
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    @MainActor
    static func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
            return
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preferences.users") {
            NSWorkspace.shared.open(url)
        }
    }
}
