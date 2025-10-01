import Foundation

struct PlanCaps {
    static let minutes: [String: Int] = [
        "free": 30,
        "standard": 120,
        "premium": 600,
        "own_key": 10000
    ]
}

enum UsageError: Error {
    case network
    case badResponse
    case decoding
    case timeout
}

struct UsageSnapshot: Codable {
    let plan: String
    let seconds_used: Int
}

@MainActor
final class UsageQuotaClient {
    static let shared = UsageQuotaClient()
    private init() {}

    private let ingestURL = "https://rhfhateyqdiysgooiqtd.functions.supabase.co/ingest"
    private let usageURL = "https://rhfhateyqdiysgooiqtd.functions.supabase.co/usage"
    private let cacheKey = "usage_snapshot"

    // MARK: - Period Calculation

    func currentPeriodYM() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    // MARK: - User Key Resolution

    func resolveUserKey() async -> String {
        // 1. Try appAccountToken from SubscriptionPlanResolver
        if let token = await SubscriptionPlanResolver.shared.appAccountToken() {
            return token.uuidString
        }

        // 2. Try originalTransactionID
        if let originalTxnID = await SubscriptionPlanResolver.shared.originalTransactionID() {
            return originalTxnID
        }

        // 3. Fallback to Keychain UUID
        return KeychainHelper.shared.getUserKey()
    }

    // MARK: - Fetch Usage

    func fetchUsage() async throws -> UsageSnapshot {
        let userKey = await resolveUserKey()
        let periodYM = currentPeriodYM()

        let payload: [String: Any] = [
            "op": "get_usage",
            "userKey": userKey,
            "periodYM": periodYM
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            throw UsageError.badResponse
        }

        var request = URLRequest(url: URL(string: usageURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 8.0

        // First attempt
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw UsageError.badResponse
            }

            let snapshot = try JSONDecoder().decode(UsageSnapshot.self, from: data)
            cacheSnapshot(snapshot)
            return snapshot
        } catch {
            // Retry once with jitter
            try await Task.sleep(nanoseconds: UInt64.random(in: 100_000_000...500_000_000))

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw UsageError.badResponse
                }

                let snapshot = try JSONDecoder().decode(UsageSnapshot.self, from: data)
                cacheSnapshot(snapshot)
                return snapshot
            } catch {
                // Return cached fallback
                if let cached = getCachedSnapshot() {
                    print("⚠️ UsageQuotaClient: Network failed, using cached snapshot")
                    return cached
                }
                throw UsageError.network
            }
        }
    }

    // MARK: - Book Seconds

    func bookSeconds(_ seconds: Int, plan: String, recordedAt: Date?) async {
        let userKey = await resolveUserKey()
        let periodYM = currentPeriodYM()

        let payload: [String: Any] = [
            "userKey": userKey,
            "secondsUsed": seconds,
            "plan": plan,
            "periodYM": periodYM,
            "recordedAt": recordedAt?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            return
        }

        var request = URLRequest(url: URL(string: ingestURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 8.0

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                // Update local cache optimistically
                if var cached = getCachedSnapshot() {
                    cached = UsageSnapshot(plan: plan, seconds_used: cached.seconds_used + seconds)
                    cacheSnapshot(cached)
                }
                print("✅ UsageQuotaClient: Booked \(seconds)s to backend")
            }
        } catch {
            print("⚠️ UsageQuotaClient: Failed to book seconds: \(error)")
        }
    }

    // MARK: - Minutes Left

    func minutesLeft(plan: String, secondsUsed: Int) -> Int {
        let cap = PlanCaps.minutes[plan] ?? 0
        let used = Int(ceil(Double(secondsUsed) / 60.0))
        return max(0, cap - used)
    }

    // MARK: - Cache Management

    private func cacheSnapshot(_ snapshot: UsageSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func getCachedSnapshot() -> UsageSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let snapshot = try? JSONDecoder().decode(UsageSnapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }
}
