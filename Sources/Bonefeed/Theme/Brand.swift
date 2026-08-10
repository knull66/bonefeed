import Foundation

enum Brand {
    static let name = "Bonefeed"
    static let nameUpper = "BONEFEED"

    static var tagline: String { L10n.t("brand.tagline") }
    static var settingsTitle: String { L10n.t("brand.settingsTitle") }
    static var quitTitle: String { L10n.t("brand.quit") }

    /// Studio credit (maker) — not the product brand.
    static let studioName = "Vibes District"
    static let studioURL = URL(string: "https://www.vibesdistrict.pro")

    /// Public marketing site.
    static let siteURL = URL(string: "https://bonefeed.netlify.app")
    static let siteHost = "bonefeed.netlify.app"

    /// Bundle / IAP identifiers (Mac App Store).
    static let bundleID = "app.bonefeed.macos"
    static let proProductID = "app.bonefeed.macos.pro"
    /// VIP Signals desk (includes Pro entitlements).
    static let vipProductID = "app.bonefeed.macos.vip"
}
