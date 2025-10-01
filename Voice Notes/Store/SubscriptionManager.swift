import Foundation
import StoreKit

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var products: [Product] = []
    @Published var activeSubscription: EchoProductID?
    @Published var isLoading = false
    @Published var purchaseError: String?

    private var updateListenerTask: Task<Void, Error>?

    private init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Product Loading

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let productIDs = EchoProductID.allCases.map { $0.rawValue }
            let loadedProducts = try await Product.products(for: productIDs)

            // Sort by price (lowest to highest)
            products = loadedProducts.sorted { $0.price < $1.price }
        } catch {
            print("Failed to load products: \(error)")
            purchaseError = "Failed to load subscription options"
        }
    }

    // MARK: - Subscription Status

    func updateSubscriptionStatus() async {
        print("🔐 SubscriptionManager: Checking subscription status...")
        var activeProductID: EchoProductID?
        var foundTransactions = 0

        for await result in Transaction.currentEntitlements {
            foundTransactions += 1
            do {
                let transaction = try checkVerified(result)
                print("🔐 Found transaction #\(foundTransactions): \(transaction.productID)")

                // Check if this is one of our subscription products and it's not expired
                if let productID = EchoProductID(rawValue: transaction.productID),
                   transaction.revocationDate == nil {
                    print("🔐 ✅ Active subscription found: \(productID.displayName)")
                    activeProductID = productID
                    break
                }
            } catch {
                print("🔐 Failed to verify transaction: \(error)")
            }
        }

        print("🔐 Total transactions found: \(foundTransactions)")

        if let active = activeProductID {
            print("🔐 Setting active subscription to: \(active.displayName) (\(active.monthlyMinutes) min)")
        } else {
            print("🔐 No active subscription - using free tier")
        }

        // Update on main actor since class is @MainActor
        activeSubscription = activeProductID
        print("🔐 Active subscription property updated, current value: \(activeSubscription?.displayName ?? "nil")")
    }

    var isSubscribed: Bool {
        activeSubscription != nil
    }

    var currentMonthlyMinutes: Int {
        if let active = activeSubscription {
            return active.monthlyMinutes
        }
        return FreeTier.monthlyMinutes
    }

    var isOwnKeySubscriber: Bool {
        activeSubscription == .ownKey
    }

    var hasApiKeyConfigured: Bool {
        let aiSettings = AISettingsStore.shared
        // Check if any provider other than appDefault has an API key
        return AIProviderType.allCases.contains { provider in
            provider != .appDefault && aiSettings.hasApiKey(for: provider)
        }
    }

    var canRecord: Bool {
        // If Own Key subscriber, they must have an API key configured
        if isOwnKeySubscriber {
            return hasApiKeyConfigured
        }
        return true
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws {
        print("🛒 SubscriptionManager: Starting purchase for \(product.displayName)")
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            print("🛒 Purchase successful, verifying...")
            let transaction = try checkVerified(verification)
            print("🛒 Transaction verified: \(transaction.productID)")
            await transaction.finish()
            print("🛒 Transaction finished, updating subscription status...")
            await updateSubscriptionStatus()
            print("🛒 Purchase complete!")

        case .userCancelled:
            print("🛒 User cancelled purchase")
            // User cancelled, no error
            break

        case .pending:
            print("🛒 Purchase pending approval")
            purchaseError = "Purchase is pending approval"

        @unknown default:
            print("🛒 Unknown purchase result")
            purchaseError = "Unknown purchase result"
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }

        try await AppStore.sync()
        await updateSubscriptionStatus()
    }

    // MARK: - Transaction Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { @MainActor in
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await transaction.finish()
                    await self.updateSubscriptionStatus()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }

    // MARK: - Helper Methods

    func product(for productID: EchoProductID) -> Product? {
        products.first { $0.id == productID.rawValue }
    }

    func displayPrice(for productID: EchoProductID) -> String {
        guard let product = product(for: productID) else {
            return "Loading..."
        }
        return product.displayPrice
    }
}

// MARK: - Store Errors

enum StoreError: Error {
    case failedVerification
}

extension StoreError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Your purchase could not be verified. Please try again."
        }
    }
}
