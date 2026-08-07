import AppKit
import Foundation
import UserNotifications

enum AppNotifier {
    static let bundleID = Brand.bundleID

    private static let didSendRegistrationPingKey = "bonefeed.didSendRegistrationPing"

    /// Call once at launch: registers categories + asks permission if needed.
    static func bootstrap() async {
        let center = UNUserNotificationCenter.current()

        let general = UNNotificationCategory(
            identifier: "CHAIN_ISLAND_GENERAL",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([general])

        let status = await authorizationStatus()
        if status == .notDetermined {
            _ = await requestAuthorization(sendRegistrationPing: true)
        }
    }

    @discardableResult
    static func requestAuthorization(sendRegistrationPing: Bool = false) async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            // `.provisional` helps macOS register the app even if the user
            // dismisses the dialog; banners still work quietly.
            let granted = try await center.requestAuthorization(options: [
                .alert, .sound, .badge, .provisional
            ])
            let status = await authorizationStatus()
            // One-time quiet ping so macOS lists the app in Notifications.
            let alreadyPinged = UserDefaults.standard.bool(forKey: didSendRegistrationPingKey)
            if sendRegistrationPing, !alreadyPinged, granted || status == .provisional || status == .authorized {
                UserDefaults.standard.set(true, forKey: didSendRegistrationPingKey)
                await notify(
                    title: Brand.name,
                    body: L10n.t("notify.readyBody"),
                    sound: false
                )
            }
            return granted
        } catch {
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    static func notify(title: String, body: String, sound: Bool) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            break
        case .notDetermined:
            let ok = await requestAuthorization()
            let status = await authorizationStatus()
            guard ok || status == .provisional || status == .authorized else { return }
        case .denied:
            return
        @unknown default:
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound ? .default : nil
        content.categoryIdentifier = "CHAIN_ISLAND_GENERAL"
        content.threadIdentifier = "chain-island"

        let request = UNNotificationRequest(
            identifier: "bonefeed-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        do {
            try await center.add(request)
        } catch {
            // Ignore delivery errors; status text covers permission issues.
        }
    }

    static func notify(alert: IslandAlert, sound: Bool) async {
        await notify(title: alert.title, body: alert.detail, sound: sound)
    }

    static func statusLabel(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: L10n.t("notify.notDetermined")
        case .denied: L10n.t("notify.denied")
        case .authorized: L10n.t("notify.authorized")
        case .provisional: L10n.t("notify.provisional")
        case .ephemeral: L10n.t("notify.ephemeral")
        @unknown default: "—"
        }
    }

    @MainActor
    static func openSystemNotificationSettings() {
        // macOS Ventura+
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
            return
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
}
