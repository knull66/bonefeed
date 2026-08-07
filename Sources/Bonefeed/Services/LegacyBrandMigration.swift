import Foundation

/// One-shot rename Chain Island → Bonefeed (UserDefaults + Application Support).
enum LegacyBrandMigration {
    private static let didMigrateKey = "bonefeed.didMigrateFromChainIsland"

    static func runIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: didMigrateKey) else { return }

        let pairs: [(String, String)] = [
            ("chainisland.soundEnabled", "bonefeed.soundEnabled"),
            ("chainisland.notificationsEnabled", "bonefeed.notificationsEnabled"),
            ("chainisland.appTheme", "bonefeed.appTheme"),
            ("chainisland.wallets", "bonefeed.wallets"),
            ("chainisland.seenBinanceDeposits", "bonefeed.seenBinanceDeposits"),
            ("chainisland.thresholds", "bonefeed.thresholds"),
            ("chainisland.watchedAssets", "bonefeed.watchedAssets"),
            ("chainisland.onboardingDone", "bonefeed.onboardingDone"),
            ("chainisland.appLanguage", "bonefeed.appLanguage"),
            ("chainisland.panelPinned", "bonefeed.panelPinned"),
            ("chainisland.panelFrame", "bonefeed.panelFrame"),
            ("chainisland.onchainBaselines.v1", "bonefeed.onchainBaselines.v1"),
            ("chainisland.portfolioHistory.v1", "bonefeed.portfolioHistory.v1"),
            ("chainisland.didSendRegistrationPing", "bonefeed.didSendRegistrationPing"),
            ("chainisland.proDebugUnlock", "bonefeed.proDebugUnlock"),
            ("chainisland.proUnlocked", "bonefeed.proUnlocked"),
        ]

        for (old, new) in pairs {
            guard defaults.object(forKey: new) == nil,
                  let value = defaults.object(forKey: old)
            else { continue }
            defaults.set(value, forKey: new)
            defaults.removeObject(forKey: old)
        }

        migrateApplicationSupport()
        defaults.set(true, forKey: didMigrateKey)
    }

    private static func migrateApplicationSupport() {
        let fm = FileManager.default
        guard let root = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let oldDir = root.appendingPathComponent("Chain Island", isDirectory: true)
        let newDir = root.appendingPathComponent("Bonefeed", isDirectory: true)
        guard fm.fileExists(atPath: oldDir.path) else { return }
        if fm.fileExists(atPath: newDir.path) {
            // Prefer new; drop old leftovers.
            try? fm.removeItem(at: oldDir)
            return
        }
        try? fm.moveItem(at: oldDir, to: newDir)
    }
}
