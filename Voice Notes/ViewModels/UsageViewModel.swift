import Foundation
import SwiftUI

@MainActor
final class UsageViewModel: ObservableObject {
    static let shared = UsageViewModel()
    private init() {}

    // MARK: - Published Properties (Backend Authoritative)

    @Published var isLoading: Bool = false
    @Published var lastRefreshAt: Date?
    @Published var secondsUsed: Int = 0
    @Published var limitSeconds: Int = 0
    @Published var currentPlan: String = "standard"  // safe default

    // MARK: - Computed Properties

    var isStale: Bool {
        guard let lastRefresh = lastRefreshAt else { return true }
        return Date().timeIntervalSince(lastRefresh) > 120  // 2 minutes
    }

    var minutesLeftText: String {
        let secondsLeft = max(limitSeconds - secondsUsed, 0)
        let minutes = secondsLeft / 60
        let seconds = secondsLeft % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var isOverLimit: Bool {
        secondsUsed >= limitSeconds
    }

    var minutesUsedDisplay: Int {
        Int(ceil(Double(secondsUsed) / 60.0))
    }

    var minutesLeftDisplay: Int {
        max((limitSeconds - secondsUsed) / 60, 0)
    }

    // MARK: - Fallback Limits (when server doesn't return limit_seconds)

    private let fallbackLimits: [String: Int] = [
        "free": 30 * 60,
        "standard": 120 * 60,
        "premium": 600 * 60,
        "own_key": 10000 * 60  // Client safety cap
    ]

    // MARK: - Refresh (Fetch from Backend)

    func refresh() async {
        isLoading = true

        do {
            // Resolve user key via StoreKit
            let userKey = await StoreKitManager.shared.resolveUserKey()
            print("📊 UsageViewModel: Resolved userKey: \(userKey.value) (source: \(userKey.source))")

            // Get current plan from StoreKit
            let plan = await StoreKitManager.shared.currentPlanIdentifier() ?? "standard"
            currentPlan = plan
            print("📊 UsageViewModel: Current plan: \(plan)")

            // Determine current period in UTC
            let periodYM = currentPeriodYM()
            print("📊 UsageViewModel: Period: \(periodYM)")

            // Fetch usage from backend
            let response = try await UsageQuotaClient.shared.fetchUsage(
                userKey: userKey.value,
                periodYM: periodYM,
                plan: plan
            )

            // Update state with backend data
            secondsUsed = response.seconds_used
            limitSeconds = response.limit_seconds ?? fallbackLimits[response.plan] ?? fallbackLimits["standard"]!
            currentPlan = response.plan
            lastRefreshAt = Date()

            print("✅ UsageViewModel: Refreshed - used: \(secondsUsed)s, limit: \(limitSeconds)s, plan: \(currentPlan)")

        } catch {
            print("❌ UsageViewModel: Refresh failed - \(error)")
            // Don't update lastRefreshAt on error - keeps isStale = true
            // Keep previous values to avoid showing 0/0
        }

        isLoading = false
    }

    // MARK: - Book Usage (Post to Backend)

    func book(seconds: Int, recordedAt: Date) async {
        do {
            // Resolve user key
            let userKey = await StoreKitManager.shared.resolveUserKey()

            print("📊 UsageViewModel: Booking \(seconds)s for user \(userKey.value), plan: \(currentPlan)")

            // Book to backend
            try await UsageQuotaClient.shared.bookUsage(
                userKey: userKey.value,
                seconds: seconds,
                plan: currentPlan,
                recordedAt: recordedAt
            )

            // Refresh to get updated usage from server
            await refresh()

        } catch {
            print("❌ UsageViewModel: Booking failed - \(error)")
        }
    }

    // MARK: - Helper

    private func currentPeriodYM() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
}
