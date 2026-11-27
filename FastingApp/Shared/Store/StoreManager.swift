import Foundation
import SwiftUI
#if (os(iOS) || os(watchOS)) && canImport(StoreKit)
import StoreKit
#endif

/// Manages StoreKit 2 lifetime non-consumable Pro purchase and entitlement checks.
@MainActor
@Observable
public final class StoreManager {
    public static let shared = StoreManager()

    public static let proLifetimeProductID = "com.antigravity.fastspan.pro.lifetime"

    public var isProUnlocked: Bool = false
    public var isPurchasing: Bool = false
    public var errorMessage: String? = nil
    /// Dynamically populated from StoreKit's `Product.displayPrice` (never hardcoded).
    public var localizedPrice: String? = nil

    #if (os(iOS) || os(watchOS)) && canImport(StoreKit)
    public var proProduct: Product? = nil
    nonisolated(unsafe) private var transactionListenerTask: Task<Void, Never>? = nil
    #endif

    public init() {
        #if (os(iOS) || os(watchOS)) && canImport(StoreKit)
        self.transactionListenerTask = listenForTransactions()
        Task { @MainActor in
            await updatePurchasedStatus()
            await loadProducts()
        }
        #endif
    }

    deinit {
        #if (os(iOS) || os(watchOS)) && canImport(StoreKit)
        transactionListenerTask?.cancel()
        #endif
    }

    #if (os(iOS) || os(watchOS)) && canImport(StoreKit)
    /// Loads product metadata from the App Store / StoreKit configuration
    public func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.proLifetimeProductID])
            if let first = products.first {
                self.proProduct = first
                self.localizedPrice = first.displayPrice
                self.errorMessage = nil
            } else {
                print("[StoreManager] No products returned for ID: \(Self.proLifetimeProductID)")
            }
        } catch {
            print("[StoreManager] Failed to load products: \(error.localizedDescription)")
        }
    }

    /// Checks the user's current signed StoreKit 2 entitlements
    public func updatePurchasedStatus() async {
        var purchased = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == Self.proLifetimeProductID && transaction.revocationDate == nil {
                    purchased = true
                    break
                }
            }
        }
        self.isProUnlocked = purchased
    }

    /// Purchases the one-time Pro lifetime unlock
    public func purchasePro() async -> Bool {
        self.errorMessage = nil
        guard let product = proProduct else {
            self.isPurchasing = true
            await loadProducts()
            guard let retryProduct = proProduct else {
                self.isPurchasing = false
                self.errorMessage = "Product \"\(Self.proLifetimeProductID)\" was not returned by the App Store. Verify the In-App Purchase is created and Ready to Submit in App Store Connect."
                return false
            }
            return await executePurchase(retryProduct)
        }
        return await executePurchase(product)
    }

    private func executePurchase(_ product: Product) async -> Bool {
        self.isPurchasing = true
        self.errorMessage = nil
        defer { self.isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    self.isProUnlocked = true
                    return true
                case .unverified(_, let error):
                    self.errorMessage = "Transaction verification failed: \(error.localizedDescription)"
                    return false
                }
            case .userCancelled:
                return false
            case .pending:
                self.errorMessage = "Purchase is pending authorization."
                return false
            @unknown default:
                return false
            }
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    /// Restores previous purchases
    public func restorePurchases() async {
        self.isPurchasing = true
        self.errorMessage = nil
        defer { self.isPurchasing = false }

        do {
            try await AppStore.sync()
            await updatePurchasedStatus()
        } catch {
            self.errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    /// Listens for background transactions (e.g. Family Sharing, external purchases)
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.updatePurchasedStatus()
                }
            }
        }
    }
    #else
    public func loadProducts() async {}
    public func updatePurchasedStatus() async {}
    public func purchasePro() async -> Bool {
        self.isProUnlocked = true
        return true
    }
    public func restorePurchases() async {}
    #endif

    // MARK: - Testing / Debug Helpers
    public func setProStatusForTesting(_ unlocked: Bool) {
        self.isProUnlocked = unlocked
    }

    #if DEBUG
    public func debugTogglePro() {
        self.isProUnlocked.toggle()
    }
    #endif
}
