import Foundation
import StoreKit

@MainActor
final class TopUpManager: ObservableObject {
    static let shared = TopUpManager()

    // Product ID for 3-hour top-up
    static let threeHoursProductID = "com.kinder.echo.3hours"

    // Seconds are determined by product metadata from App Store Connect
    // This allows changing the time without app updates
    var secondsGranted: Int {
        // Try to extract from product description or default to 3 hours
        // Format expected: "XXX minutes" or "X hours"
        if let product = threeHoursProduct {
            // Check product description for duration
            if let duration = extractDuration(from: product.description) {
                return duration
            }
        }
        // Default fallback
        return 10800 // 3 hours
    }

    private func extractDuration(from text: String) -> Int? {
        let lowercased = text.lowercased()

        // Match "X hours"
        if let hoursMatch = lowercased.range(of: #"(\d+)\s*hours?"#, options: .regularExpression) {
            let hoursString = String(lowercased[hoursMatch]).components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let hours = Int(hoursString) {
                return hours * 3600
            }
        }

        // Match "X minutes"
        if let minutesMatch = lowercased.range(of: #"(\d+)\s*minutes?"#, options: .regularExpression) {
            let minutesString = String(lowercased[minutesMatch]).components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let minutes = Int(minutesString) {
                return minutes * 60
            }
        }

        return nil
    }

    @Published var isLoading = false
    @Published var purchaseError: String?
    @Published var threeHoursProduct: Product?

    private var updateListenerTask: Task<Void, Error>?

    private init() {
        updateListenerTask = listenForTransactions()

        Task {
            await loadProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.threeHoursProductID])
            threeHoursProduct = products.first

            print("📦 TopUpManager: Loaded product: \(threeHoursProduct?.displayName ?? "none")")
        } catch {
            print("❌ TopUpManager: Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase3Hours() async throws {
        guard let product = threeHoursProduct else {
            throw TopUpError.productNotLoaded
        }

        isLoading = true
        purchaseError = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                // Verify the transaction
                let transaction = try checkVerified(verification)

                // Credit the purchase on backend
                try await creditTopUp(transaction: transaction)

                // Finish the transaction
                await transaction.finish()

                print("✅ TopUpManager: Purchase successful")

            case .userCancelled:
                print("ℹ️ TopUpManager: User cancelled purchase")

            case .pending:
                print("⏳ TopUpManager: Purchase pending")

            @unknown default:
                break
            }

        } catch {
            purchaseError = error.localizedDescription
            print("❌ TopUpManager: Purchase failed: \(error)")
            throw error
        }

        isLoading = false
    }

    // MARK: - Backend Credit

    private func creditTopUp(transaction: Transaction) async throws {
        // Get user key
        let userKey = await StoreKitManager.shared.resolveUserKey()

        // Get transaction ID for idempotency
        guard let transactionID = transaction.originalID.description as String? else {
            throw TopUpError.invalidTransaction
        }

        // Extract price and currency from transaction
        let pricePaid: Decimal? = transaction.price
        let currency: String? = transaction.currency?.identifier
        let seconds = await self.secondsGranted

        print("📊 TopUpManager: Crediting \(seconds)s to backend for user \(userKey.value), txn: \(transactionID), price: \(pricePaid?.description ?? "nil") \(currency ?? "nil")")

        // Call backend to credit the purchase
        try await UsageQuotaClient.shared.creditTopUp(
            userKey: userKey.value,
            seconds: seconds,
            transactionID: transactionID,
            pricePaid: pricePaid,
            currency: currency
        )

        // Refresh usage to show updated balance
        // Clear debug override to show real purchased balance
        await UsageViewModel.shared.refresh(clearDebugOverride: true)

        print("✅ TopUpManager: Backend credited successfully")
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Iterate through any transactions that don't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)

                    // Check if this is our consumable
                    if transaction.productID == Self.threeHoursProductID {
                        // Credit on backend
                        try await self.creditTopUp(transaction: transaction)

                        // Finish the transaction
                        await transaction.finish()
                    }
                } catch {
                    print("❌ TopUpManager: Transaction verification failed: \(error)")
                }
            }
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw TopUpError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Display Helpers

    var displayPrice: String {
        // Use the actual localized price from StoreKit
        // This automatically shows the correct currency and price for the user's region
        // e.g., "$9.99" in US, "€9,99" in Europe, "¥1,200" in Japan
        threeHoursProduct?.displayPrice ?? "Loading..."
    }

    var displayName: String {
        // Use the display name from App Store Connect
        // e.g., "3 Hours Recording Time", "5 Hours Recording Time", etc.
        threeHoursProduct?.displayName ?? "Add Recording Time"
    }

    var displayDescription: String {
        // Use the description from App Store Connect
        // e.g., "Add 3 hours of recording time"
        threeHoursProduct?.description ?? "Add recording time to your account"
    }

    var isAvailable: Bool {
        threeHoursProduct != nil
    }
}

// MARK: - Errors

enum TopUpError: Error, LocalizedError {
    case productNotLoaded
    case failedVerification
    case invalidTransaction
    case backendError(String)

    var errorDescription: String? {
        switch self {
        case .productNotLoaded:
            return "Product not available. Please try again."
        case .failedVerification:
            return "Purchase verification failed."
        case .invalidTransaction:
            return "Invalid transaction ID."
        case .backendError(let message):
            return "Server error: \(message)"
        }
    }
}
