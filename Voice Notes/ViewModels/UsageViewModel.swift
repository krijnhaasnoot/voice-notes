import Foundation
import SwiftUI

@MainActor
final class UsageViewModel: ObservableObject {
    static let shared = UsageViewModel()
    private init() {}

    @Published var plan: AppPlan = .free
    @Published var secondsUsed: Int = 0
    @Published var minutesLeft: Int = 0
    @Published var isOverLimit: Bool = false
    @Published var isLoading: Bool = false

    func refresh() async {
        isLoading = true

        // Get current plan
        plan = await SubscriptionPlanResolver.shared.currentPlan()

        // Fetch usage from backend
        if let snapshot = try? await UsageQuotaClient.shared.fetchUsage() {
            secondsUsed = snapshot.seconds_used
            minutesLeft = UsageQuotaClient.shared.minutesLeft(plan: snapshot.plan, secondsUsed: snapshot.seconds_used)
        } else {
            // Fallback: use plan-based calculation
            minutesLeft = UsageQuotaClient.shared.minutesLeft(plan: plan.rawValue, secondsUsed: secondsUsed)
        }

        isOverLimit = (minutesLeft <= 0)
        isLoading = false

        print("📊 UsageViewModel: plan=\(plan.rawValue), used=\(secondsUsed)s, left=\(minutesLeft)min, overLimit=\(isOverLimit)")
    }

    func book(seconds: Int, recordedAt: Date?) async {
        let planString = plan.rawValue
        await UsageQuotaClient.shared.bookSeconds(seconds, plan: planString, recordedAt: recordedAt)
        await refresh()
    }

    var minutesUsedDisplay: Int {
        Int(ceil(Double(secondsUsed) / 60.0))
    }

    var formattedMinutesLeft: String {
        let totalSeconds = minutesLeft * 60
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
