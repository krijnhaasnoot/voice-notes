import Foundation
import StoreKit

enum AppPlan: String, Codable {
    case free
    case standard
    case premium
    case own_key
}

@MainActor
final class SubscriptionPlanResolver {
    static let shared = SubscriptionPlanResolver()
    private init() {}

    // Map App Store product IDs to plans
    private let productIDToPlan: [String: AppPlan] = [
        "6753187339": .standard,  // Echo Standard
        "6753187348": .premium,   // Echo Premium
        "6753187356": .own_key    // Echo Own Key
    ]

    // MARK: - Current Plan

    func currentPlan() async -> AppPlan {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }

            if let plan = productIDToPlan[transaction.productID] {
                return plan
            }
        }

        return .free
    }

    // MARK: - App Account Token

    func appAccountToken() async -> UUID? {
        // Check if we have stored an appAccountToken during purchase
        // For now, return nil as we haven't implemented token storage yet
        // You can enhance this to store/retrieve the token during purchase flow
        return nil
    }

    // MARK: - Original Transaction ID

    func originalTransactionID() async -> String? {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }

            // Return the first valid original transaction ID
            return String(transaction.originalID)
        }

        return nil
    }
}
