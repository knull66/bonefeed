import Foundation

enum Brand {
    static let name = "Bonefeed"
    static let nameUpper = "BONEFEED"

    static var tagline: String { L10n.t("brand.tagline") }
    static var settingsTitle: String { L10n.t("brand.settingsTitle") }
    static var quitTitle: String { L10n.t("brand.quit") }

    /// Bundle / IAP identifiers (Mac App Store).
    static let bundleID = "app.bonefeed.macos"
    static let proProductID = "app.bonefeed.macos.pro"
}
