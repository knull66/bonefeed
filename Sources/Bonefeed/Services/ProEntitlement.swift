import Foundation
import StoreKit

/// Free vs Pro gates + StoreKit 2 purchase for Bonefeed Pro (non-consumable).
enum ProLimits {
    static let freeWalletCap = 1
    static let freeWatchlistCap = 3
    static let freeThemes: Set<AppTheme> = [.cyberDark, .macDark]

    /// Must match App Store Connect + Products.storekit.
    static let storeProductID = Brand.proProductID

    /// Local unlock for pre-App Store builds. Set to `false` before Mac App Store release.
    static let allowLocalUnlock = true
}

extension Notification.Name {
    static let bonefeedProStatusChanged = Notification.Name("bonefeed.proStatusChanged")
}

@MainActor
@Observable
final class ProStore {
    static let shared = ProStore()

    private(set) var isPro = false
    private(set) var product: Product?
    private(set) var priceText: String?
    private(set) var isPurchasing = false
    private(set) var isRefreshing = false
    private(set) var lastError: String?

    private var updatesTask: Task<Void, Never>?
    private let debugUnlockKey = "bonefeed.proDebugUnlock"

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
            let products = try await Product.products(for: [ProLimits.storeProductID])
            product = products.first
            priceText = products.first?.displayPrice
            lastError = products.isEmpty
                ? "Product unavailable (check App Store Connect / StoreKit config)."
                : nil
        } catch {
            lastError = error.localizedDescription
            product = nil
            priceText = nil
        }
    }

    func refreshEntitlements() async {
        isRefreshing = true
        defer { isRefreshing = false }

        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == ProLimits.storeProductID,
               transaction.revocationDate == nil {
                entitled = true
                break
            }
        }

        if ProLimits.allowLocalUnlock,
           UserDefaults.standard.bool(forKey: debugUnlockKey) {
            entitled = true
        }

        // Migrate legacy early-access flag once (pre-StoreKit builds).
        let legacyKey = "bonefeed.proUnlocked"
        if UserDefaults.standard.bool(forKey: legacyKey) {
            if ProLimits.allowLocalUnlock {
                UserDefaults.standard.set(true, forKey: debugUnlockKey)
                entitled = true
            }
            UserDefaults.standard.removeObject(forKey: legacyKey)
        }

        let changed = isPro != entitled
        isPro = entitled
        if changed {
            NotificationCenter.default.post(name: .bonefeedProStatusChanged, object: nil)
        }
    }

    func purchase() async -> Bool {
        lastError = nil
        if product == nil {
            await loadProduct()
        }
        guard let product else {
            lastError = "Bonefeed Pro is not available yet from the App Store."
            return false
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                return isPro
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
            if !isPro {
                lastError = "No Pro purchase found for this Apple ID."
            }
            return isPro
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

    func lockLocal() {
        UserDefaults.standard.set(false, forKey: debugUnlockKey)
        Task { await refreshEntitlements() }
    }

    static func isThemeAllowed(_ theme: AppTheme, isPro: Bool) -> Bool {
        isPro || ProLimits.freeThemes.contains(theme)
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        do {
            let transaction = try checkVerified(result)
            if transaction.productID == ProLimits.storeProductID {
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
