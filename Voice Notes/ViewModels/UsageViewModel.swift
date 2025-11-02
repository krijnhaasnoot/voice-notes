import Foundation
import SwiftUI

@MainActor
final class UsageViewModel: ObservableObject {
    static let shared = UsageViewModel()
    private init() {}

    // MARK: - Published Properties (Real Backend Data)

    @Published var isLoading: Bool = true
    @Published var secondsUsed: Int = 0
    @Published var limitSeconds: Int = 1800  // Default 30 min
    @Published var remainingSeconds: Int = 1800
    @Published var currentPlan: String = "free"
    @Published var lastRefreshAt: Date?
    @Published var isDebugOverrideActive: Bool = false  // For debug settings

    // MARK: - Computed Properties

    var isStale: Bool {
        guard let lastRefresh = lastRefreshAt else { return true }
        return Date().timeIntervalSince(lastRefresh) > 120  // 2 minutes
    }

    var minutesLeftText: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var isOverLimit: Bool {
        secondsUsed >= limitSeconds
    }

    var minutesUsedDisplay: Int {
        Int(ceil(Double(secondsUsed) / 60.0))
    }

    var minutesLeftDisplay: Int {
        max(remainingSeconds / 60, 0)
    }

    // MARK: - API Client

    private let api = UsageAPI()

    // MARK: - User Key Resolution

    private var userKey: String {
        // Use device identifier as user key for free tier
        // TODO: Replace with StoreKit original transaction ID for paid users
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
    }

    // MARK: - Fetch Usage from Backend

    func refresh() async {
        isLoading = true

        do {
            print("📊 UsageViewModel: Fetching usage for user: \(userKey)")

            let json = try await api.post("/ingest/usage/fetch", body: [
                "user_key": userKey,
                "plan": currentPlan
            ])

            // Parse response
            self.secondsUsed = (json["seconds_used"] as? Int) ?? 0
            self.limitSeconds = (json["limit_seconds"] as? Int) ?? 1800
            self.remainingSeconds = max(limitSeconds - secondsUsed, 0)

            if let plan = json["plan"] as? String {
                self.currentPlan = plan
            }

            self.lastRefreshAt = Date()

            print("✅ UsageViewModel: Refresh complete - used: \(secondsUsed)s, limit: \(limitSeconds)s, remaining: \(remainingSeconds)s")

        } catch {
            print("❌ UsageViewModel: Refresh failed - \(error)")
            // Keep previous values on error to avoid showing 0/0
            // Don't update lastRefreshAt so isStale remains true
        }

        isLoading = false
    }

    // MARK: - Book Usage to Backend

    func book(seconds: Int, recordedAt: Date) async {
        do {
            print("📊 UsageViewModel: Booking \(seconds)s for user: \(userKey)")

            let body: [String: Any] = [
                "user_key": userKey,
                "seconds": seconds,
                "recorded_at": Int(recordedAt.timeIntervalSince1970),
                "plan": currentPlan
            ]

            let json = try await api.post("/ingest/usage/book", body: body)

            // Parse response (book endpoint returns updated usage)
            if let ok = json["ok"] as? Bool, ok {
                self.secondsUsed = (json["seconds_used"] as? Int) ?? 0
                self.limitSeconds = (json["limit_seconds"] as? Int) ?? 1800
                self.remainingSeconds = (json["remaining_seconds"] as? Int) ?? max(limitSeconds - secondsUsed, 0)
                self.lastRefreshAt = Date()

                print("✅ UsageViewModel: Book complete - used: \(secondsUsed)s, remaining: \(remainingSeconds)s")
            } else {
                throw NSError(domain: "UsageViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Book request returned ok:false"])
            }

        } catch {
            print("❌ UsageViewModel: Book failed - \(error)")
            // Fallback: fetch to get updated state
            print("📊 UsageViewModel: Falling back to fetch()")
            await refresh()
        }
    }
}
