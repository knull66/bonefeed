import Foundation
import StoreKit

/// Free vs Pro vs VIP gates + StoreKit 2 purchases (non-consumable).
enum ProLimits {
    static let freeWalletCap = 1
    static let freeWatchlistCap = 3
    static let freeThemes: Set<AppTheme> = [.cyberDark, .macDark]

    /// Must match App Store Connect + Products.storekit.
    static let storeProductID = Brand.proProductID
    static let vipProductID = Brand.vipProductID

    /// Local unlock for pre-App Store builds. Set to `false` before Mac App Store release.
    static let allowLocalUnlock = true

    /// VIP desk defaults — tighter than Free/Pro watchlist signals.
    static let vipPumpPercent: Double = 2.5
    static let vipDumpPercent: Double = -2.5
    static let vipFeeHigh: Double = 25
    static let vipCooldownMinutes: Int = 15
}

extension Notification.Name {
    static let bonefeedProStatusChanged = Notification.Name("bonefeed.proStatusChanged")
}

@MainActor
@Observable
final class ProStore {
    static let shared = ProStore()

    /// Pro radar (Binance / limits / themes). True if Pro **or** VIP purchased.
    private(set) var isPro = false
    /// VIP Signals desk (tight market alerts). Implies Pro.
    private(set) var isVIP = false

    private(set) var product: Product?
    private(set) var vipProduct: Product?
    private(set) var priceText: String?
    private(set) var vipPriceText: String?
    private(set) var isPurchasing = false
    private(set) var isRefreshing = false
    private(set) var lastError: String?

    private var updatesTask: Task<Void, Never>?
    private let debugUnlockKey = "bonefeed.proDebugUnlock"
    private let debugVIPUnlockKey = "bonefeed.vipDebugUnlock"

    private init() {}

    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await update in Transaction.updates {
                await self.handle(update)
            }
        }
        Task {
            await refreshEntitlements()
            await loadProduct()
        }
    }

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [
                ProLimits.storeProductID,
                ProLimits.vipProductID,
            ])
            product = products.first(where: { $0.id == ProLimits.storeProductID })
            vipProduct = products.first(where: { $0.id == ProLimits.vipProductID })
            priceText = product?.displayPrice
            vipPriceText = vipProduct?.displayPrice
            lastError = product == nil && vipProduct == nil
                ? "Products unavailable (check App Store Connect / StoreKit config)."
                : nil
        } catch {
            lastError = error.localizedDescription
            product = nil
            vipProduct = nil
            priceText = nil
            vipPriceText = nil
        }
    }

    func refreshEntitlements() async {
        isRefreshing = true
        defer { isRefreshing = false }

        var entitledPro = false
        var entitledVIP = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.revocationDate == nil else { continue }
            if transaction.productID == ProLimits.vipProductID {
                entitledVIP = true
                entitledPro = true
            } else if transaction.productID == ProLimits.storeProductID {
                entitledPro = true
            }
        }

        if ProLimits.allowLocalUnlock {
            if UserDefaults.standard.bool(forKey: debugVIPUnlockKey) {
                entitledVIP = true
                entitledPro = true
            }
            if UserDefaults.standard.bool(forKey: debugUnlockKey) {
                entitledPro = true
            }
        }

        // Migrate legacy early-access flag once (pre-StoreKit builds).
        let legacyKey = "bonefeed.proUnlocked"
        if UserDefaults.standard.bool(forKey: legacyKey) {
            if ProLimits.allowLocalUnlock {
                UserDefaults.standard.set(true, forKey: debugUnlockKey)
                entitledPro = true
            }
            UserDefaults.standard.removeObject(forKey: legacyKey)
        }

        let changed = isPro != entitledPro || isVIP != entitledVIP
        isPro = entitledPro
        isVIP = entitledVIP
        if changed {
            NotificationCenter.default.post(name: .bonefeedProStatusChanged, object: nil)
        }
    }

    func purchase() async -> Bool {
        await purchase(productID: ProLimits.storeProductID)
    }

    func purchaseVIP() async -> Bool {
        await purchase(productID: ProLimits.vipProductID)
    }

    private func purchase(productID: String) async -> Bool {
        lastError = nil
        if product == nil || vipProduct == nil {
            await loadProduct()
        }
        let target = productID == ProLimits.vipProductID ? vipProduct : product
        guard let target else {
            lastError = productID == ProLimits.vipProductID
                ? "Bonefeed VIP is not available yet from the App Store."
                : "Bonefeed Pro is not available yet from the App Store."
            return false
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await target.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                return productID == ProLimits.vipProductID ? isVIP : isPro
            case .userCancelled:
                lastError = nil
                return false
            case .pending:
                lastError = "Purchase pending approval."
                return false
            @unknown default:
                lastError = "Unknown purchase result."
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Restores purchases for this Apple ID (may prompt for App Store login).
    func restore() async -> Bool {
        lastError = nil
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            try await StoreKit.AppStore.sync()
            await refreshEntitlements()
            if !isPro && !isVIP {
                lastError = "No Pro / VIP purchase found for this Apple ID."
            }
            return isPro || isVIP
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func unlockLocal() {
        guard ProLimits.allowLocalUnlock else { return }
        UserDefaults.standard.set(true, forKey: debugUnlockKey)
        isPro = true
        NotificationCenter.default.post(name: .bonefeedProStatusChanged, object: nil)
    }

    func unlockVIPLocal() {
        guard ProLimits.allowLocalUnlock else { return }
        UserDefaults.standard.set(true, forKey: debugVIPUnlockKey)
        UserDefaults.standard.set(true, forKey: debugUnlockKey)
        isVIP = true
        isPro = true
        NotificationCenter.default.post(name: .bonefeedProStatusChanged, object: nil)
    }

    func lockLocal() {
        UserDefaults.standard.set(false, forKey: debugUnlockKey)
        UserDefaults.standard.set(false, forKey: debugVIPUnlockKey)
        Task { await refreshEntitlements() }
    }

    static func isThemeAllowed(_ theme: AppTheme, isPro: Bool) -> Bool {
        isPro || ProLimits.freeThemes.contains(theme)
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        do {
            let transaction = try checkVerified(result)
            if transaction.productID == ProLimits.storeProductID
                || transaction.productID == ProLimits.vipProductID {
                await transaction.finish()
                await refreshEntitlements()
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
