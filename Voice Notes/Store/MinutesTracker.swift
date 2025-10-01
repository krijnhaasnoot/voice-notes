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
        // Check if we need to reset for new month
        if let storedPeriodStart = userDefaults.object(forKey: periodStartKey) as? Date {
            currentPeriodStart = storedPeriodStart

            // If more than 30 days have passed, reset the period
            if Calendar.current.dateComponents([.day], from: storedPeriodStart, to: Date()).day ?? 0 >= 30 {
                resetPeriod()
            } else {
                minutesUsed = userDefaults.double(forKey: minutesUsedKey)
            }
        } else {
            // First launch
            resetPeriod()
        }
    }

    private func saveData() {
        userDefaults.set(minutesUsed, forKey: minutesUsedKey)
        userDefaults.set(currentPeriodStart, forKey: periodStartKey)
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
        print("📊 MinutesTracker: Adding \(minutes) minutes (from \(seconds) seconds)")
        print("📊 Before: \(minutesUsed) min used, \(minutesRemaining) min remaining")

        minutesUsed += minutes
        saveData()
        updateLimits()

        print("📊 After: \(minutesUsed) min used, \(minutesRemaining) min remaining")

        // Force UI update
        objectWillChange.send()
    }

    func addUsage(minutes: Double) {
        print("📊 MinutesTracker: Adding \(minutes) minutes directly")
        print("📊 Before: \(minutesUsed) min used, \(minutesRemaining) min remaining")

        minutesUsed += minutes
        saveData()
        updateLimits()

        print("📊 After: \(minutesUsed) min used, \(minutesRemaining) min remaining")

        // Force UI update
        objectWillChange.send()
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
        String(format: "%.1f", max(0, minutesRemaining))
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
