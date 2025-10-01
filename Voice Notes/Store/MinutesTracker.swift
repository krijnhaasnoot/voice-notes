import Foundation
import Combine

@MainActor
class MinutesTracker: ObservableObject {
    static let shared = MinutesTracker()

    @Published var minutesUsed: Double = 0
    @Published var minutesRemaining: Double = 0
    @Published var monthlyLimit: Int = FreeTier.monthlyMinutes
    @Published var currentPeriodStart: Date = Date()
    @Published var canRecord: Bool = true

    private let subscriptionManager = SubscriptionManager.shared
    private var cancellables = Set<AnyCancellable>()

    private let userDefaults = UserDefaults.standard
    private let minutesUsedKey = "com.echo.minutesUsed"
    private let periodStartKey = "com.echo.periodStart"

    private init() {
        loadStoredData()
        setupSubscriptionObserver()
        updateLimits()
    }

    // MARK: - Storage

    private func loadStoredData() {
        print("📊 MinutesTracker: Loading stored data...")

        // Check if we need to reset for new month (only for paid subscriptions)
        if let storedPeriodStart = userDefaults.object(forKey: periodStartKey) as? Date {
            currentPeriodStart = storedPeriodStart
            let daysSince = Calendar.current.dateComponents([.day], from: storedPeriodStart, to: Date()).day ?? 0

            print("📊 Period started: \(storedPeriodStart), days since: \(daysSince)")

            // If more than 30 days have passed and user has a paid subscription, reset the period
            // Free tier never resets - it's a one-time 30 minute trial
            if daysSince >= 30 && !isFreeTier {
                print("📊 Period expired, resetting...")
                resetPeriod()
            } else {
                let storedMinutes = userDefaults.double(forKey: minutesUsedKey)
                minutesUsed = storedMinutes
                print("📊 Loaded \(String(format: "%.2f", storedMinutes)) minutes from storage")
            }
        } else {
            // First launch
            print("📊 First launch - initializing period")
            resetPeriod()
        }

        print("📊 Initial state: \(String(format: "%.2f", minutesUsed)) min used")
    }

    private func saveData() {
        userDefaults.set(minutesUsed, forKey: minutesUsedKey)
        userDefaults.set(currentPeriodStart, forKey: periodStartKey)
        userDefaults.synchronize() // Force immediate write
        print("📊 Saved \(String(format: "%.2f", minutesUsed)) minutes to UserDefaults")
    }

    private func resetPeriod() {
        currentPeriodStart = Date()
        minutesUsed = 0
        saveData()
        updateLimits()
    }

    // MARK: - Subscription Observer

    private func setupSubscriptionObserver() {
        subscriptionManager.$activeSubscription
            .sink { [weak self] subscription in
                print("📊 MinutesTracker: Subscription changed to \(subscription?.displayName ?? "Free Trial")")
                self?.updateLimits()
            }
            .store(in: &cancellables)
    }

    // MARK: - Limits Calculation

    private func updateLimits() {
        monthlyLimit = subscriptionManager.currentMonthlyMinutes
        minutesRemaining = max(0, Double(monthlyLimit) - minutesUsed)

        // For Own Key subscribers, also check API key
        if subscriptionManager.isOwnKeySubscriber {
            canRecord = minutesRemaining > 0 && subscriptionManager.hasApiKeyConfigured
        } else {
            canRecord = minutesRemaining > 0
        }

        print("📊 MinutesTracker: Updated limits - \(monthlyLimit) total, \(minutesUsed) used, \(minutesRemaining) remaining, canRecord: \(canRecord)")
    }

    // MARK: - Usage Tracking

    func addUsage(seconds: Double) {
        let minutes = seconds / 60.0
        print("📊 MinutesTracker: Adding \(String(format: "%.2f", minutes)) minutes (from \(String(format: "%.1f", seconds)) seconds)")
        print("📊 Before: \(String(format: "%.2f", minutesUsed)) min used, \(String(format: "%.2f", minutesRemaining)) min remaining, limit: \(monthlyLimit)")

        // Update the value
        let newUsed = minutesUsed + minutes
        minutesUsed = newUsed

        // Save to UserDefaults
        saveData()

        // Recalculate limits and remaining
        updateLimits()

        print("📊 After: \(String(format: "%.2f", minutesUsed)) min used, \(String(format: "%.2f", minutesRemaining)) min remaining")
        print("📊 Published properties updated - triggering UI refresh")
    }

    func addUsage(minutes: Double) {
        print("📊 MinutesTracker: Adding \(String(format: "%.2f", minutes)) minutes directly")
        print("📊 Before: \(String(format: "%.2f", minutesUsed)) min used, \(String(format: "%.2f", minutesRemaining)) min remaining, limit: \(monthlyLimit)")

        // Update the value
        let newUsed = minutesUsed + minutes
        minutesUsed = newUsed

        // Save to UserDefaults
        saveData()

        // Recalculate limits and remaining
        updateLimits()

        print("📊 After: \(String(format: "%.2f", minutesUsed)) min used, \(String(format: "%.2f", minutesRemaining)) min remaining")
        print("📊 Published properties updated - triggering UI refresh")
    }

    // MARK: - Check Availability

    func canRecordDuration(seconds: Double) -> Bool {
        let minutes = seconds / 60.0
        return minutesRemaining >= minutes
    }

    // MARK: - Reset (for testing or manual reset)

    func manualReset() {
        resetPeriod()
    }

    // MARK: - Computed Properties

    var usagePercentage: Double {
        guard monthlyLimit > 0 else { return 0 }
        return min(1.0, minutesUsed / Double(monthlyLimit))
    }

    var isNearLimit: Bool {
        usagePercentage >= 0.8
    }

    var isAtLimit: Bool {
        minutesRemaining <= 0
    }

    var formattedMinutesUsed: String {
        String(format: "%.1f", minutesUsed)
    }

    var formattedMinutesRemaining: String {
        let totalSeconds = max(0, minutesRemaining * 60)
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var nextResetDate: Date {
        Calendar.current.date(byAdding: .day, value: 30, to: currentPeriodStart) ?? Date()
    }

    var daysUntilReset: Int {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: nextResetDate).day ?? 0
        return max(0, days)
    }

    // MARK: - Tier Info

    var currentTierName: String {
        if let subscription = subscriptionManager.activeSubscription {
            return subscription.displayName
        }
        return FreeTier.displayName
    }

    var isFreeTier: Bool {
        subscriptionManager.activeSubscription == nil
    }
}
