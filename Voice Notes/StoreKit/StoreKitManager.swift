import Foundation
import StoreKit

enum UserKeySource {
    case originalTransactionID
    case appAccountToken
    case deviceUUID
}

struct UserKey {
    let value: String
    let source: UserKeySource
}

@MainActor
final class StoreKitManager {
    static let shared = StoreKitManager()
    private init() {}

    // MARK: - User Key Resolution (Priority: originalTransactionID > appAccountToken > Keychain UUID)

    func resolveUserKey() async -> UserKey {
        // 1. Try originalTransactionID from StoreKit entitlements
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }

            // Found a valid entitlement, use its originalID
            let originalID = String(transaction.originalID)
            print("✅ StoreKitManager: Using originalTransactionID: \(originalID)")
            return UserKey(value: originalID, source: .originalTransactionID)
        }

        // 2. Try appAccountToken (if we stored one during purchase)
        // For now, we don't have appAccountToken storage implemented
        // This would require storing it during purchase flow

        // 3. Fallback to Keychain UUID
        let deviceUUID = KeychainHelper.shared.getUserKey()
        print("⚠️ StoreKitManager: No originalTransactionID found, using deviceUUID: \(deviceUUID)")
        return UserKey(value: deviceUUID, source: .deviceUUID)
    }

    // MARK: - Current Plan Identifier

    func currentPlanIdentifier() async -> String? {
        // Map StoreKit product IDs to plan identifiers
        let productIDToPlan: [String: String] = [
            "com.kinder.echo.standard.monthly": "standard",
            "com.kinder.echo.premium.monthly": "premium",
            "com.kinder.echo.ownkey.monthly": "own_key"
        ]

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }

            if let plan = productIDToPlan[transaction.productID] {
                print("✅ StoreKitManager: Current plan: \(plan) (productID: \(transaction.productID))")
                return plan
            }
        }

        // No active subscription found
        print("⚠️ StoreKitManager: No active subscription, defaulting to 'free'")
        return nil  // Caller should default to "free" or "standard"
    }
}
