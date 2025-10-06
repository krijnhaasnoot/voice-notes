import Foundation

struct UsageResponse: Decodable {
    let plan: String
    let seconds_used: Int
    let limit_seconds: Int?
}

enum UsageQuotaError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse(statusCode: Int, body: String)
    case decodingError(Error)
    case timeout
}

final class UsageQuotaClient {
    static let shared = UsageQuotaClient()
    private init() {}

    private let timeout: TimeInterval = 30.0

    private var baseURL: String {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "INGEST_URL") as? String else {
            return "https://rhfhateyqdiysgooiqtd.functions.supabase.co"
        }
        return url
    }

    private var analyticsToken: String? {
        let token = Bundle.main.object(forInfoDictionaryKey: "ANALYTICS_TOKEN") as? String
        if token == nil || token?.isEmpty == true {
            print("⚠️ UsageQuotaClient: ANALYTICS_TOKEN is missing or empty!")
        }
        return token
    }

    // MARK: - Fetch Usage

    func fetchUsage(userKey: String, periodYM: String) async throws -> UsageResponse {
        let endpoint = "\(baseURL)/ingest/usage/fetch"
        guard let url = URL(string: endpoint) else {
            throw UsageQuotaError.invalidURL
        }

        let payload: [String: Any] = [
            "user_key": userKey,
            "period_ym": periodYM
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            throw UsageQuotaError.invalidResponse(statusCode: 0, body: "Failed to serialize request")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = analyticsToken {
            print("🔑 UsageQuotaClient: [fetchUsage] Using token: \(token.prefix(10))...")
            request.setValue(token, forHTTPHeaderField: "x-analytics-token")
        } else {
            print("⚠️ UsageQuotaClient: [fetchUsage] NO TOKEN - this will fail with 401!")
        }
        request.httpBody = jsonData
        request.timeoutInterval = timeout

        let startTime = Date()
        print("📤 UsageQuotaClient: [fetchUsage] Request to \(endpoint) at \(startTime)")

        var responseData: Data?

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            responseData = data
            let elapsed = Date().timeIntervalSince(startTime)
            print("📥 UsageQuotaClient: [fetchUsage] Response received in \(String(format: "%.2f", elapsed))s")

            guard let httpResponse = response as? HTTPURLResponse else {
                throw UsageQuotaError.invalidResponse(statusCode: 0, body: "Not HTTP response")
            }

            guard httpResponse.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("❌ UsageQuotaClient: [fetchUsage] Error \(httpResponse.statusCode): \(body)")
                throw UsageQuotaError.invalidResponse(statusCode: httpResponse.statusCode, body: body)
            }

            // Log raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📦 UsageQuotaClient: [fetchUsage] Raw response: \(responseString)")
            }

            let decoded = try JSONDecoder().decode(UsageResponse.self, from: data)
            print("✅ UsageQuotaClient: [fetchUsage] Success - used: \(decoded.seconds_used)s, limit: \(decoded.limit_seconds ?? 0)s, plan: \(decoded.plan)")
            return decoded
        } catch let error as DecodingError {
            print("❌ UsageQuotaClient: [fetchUsage] Decoding error: \(error)")
            if let data = responseData, let responseString = String(data: data, encoding: .utf8) {
                print("📦 UsageQuotaClient: [fetchUsage] Failed to decode: \(responseString)")
            }
            throw UsageQuotaError.decodingError(error)
        } catch let error as UsageQuotaError {
            throw error
        } catch {
            print("❌ UsageQuotaClient: [fetchUsage] Network error: \(error)")
            throw UsageQuotaError.networkError(error)
        }
    }

    // MARK: - Credit Top-Up

    func creditTopUp(userKey: String, seconds: Int, transactionID: String, pricePaid: Decimal? = nil, currency: String? = nil) async throws {
        let endpoint = "\(baseURL)/usage-credit-topup"
        guard let url = URL(string: endpoint) else {
            throw UsageQuotaError.invalidURL
        }

        var payload: [String: Any] = [
            "user_key": userKey,
            "seconds": seconds,
            "transaction_id": transactionID
        ]

        // Add optional price and currency for analytics/revenue tracking
        if let pricePaid = pricePaid {
            payload["price_paid"] = NSDecimalNumber(decimal: pricePaid).doubleValue
        }
        if let currency = currency {
            payload["currency"] = currency
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            throw UsageQuotaError.invalidResponse(statusCode: 0, body: "Failed to serialize request")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = analyticsToken {
            request.setValue(token, forHTTPHeaderField: "x-analytics-token")
        }
        request.httpBody = jsonData
        request.timeoutInterval = timeout

        let startTime = Date()
        print("📤 UsageQuotaClient: [creditTopUp] Request to \(endpoint) - user: \(userKey), seconds: \(seconds), txn: \(transactionID)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let elapsed = Date().timeIntervalSince(startTime)
            print("📥 UsageQuotaClient: [creditTopUp] Response received in \(String(format: "%.2f", elapsed))s")

            guard let httpResponse = response as? HTTPURLResponse else {
                throw UsageQuotaError.invalidResponse(statusCode: 0, body: "Not HTTP response")
            }

            guard httpResponse.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("❌ UsageQuotaClient: [creditTopUp] Error \(httpResponse.statusCode): \(body)")
                throw UsageQuotaError.invalidResponse(statusCode: httpResponse.statusCode, body: body)
            }

            let body = String(data: data, encoding: .utf8) ?? ""
            print("✅ UsageQuotaClient: [creditTopUp] Success - \(body)")
        } catch let error as UsageQuotaError {
            throw error
        } catch {
            throw UsageQuotaError.networkError(error)
        }
    }

    // MARK: - Book Usage

    func bookUsage(userKey: String, seconds: Int, plan: String, recordedAt: Date) async throws {
        let endpoint = "\(baseURL)/ingest/usage/book"
        guard let url = URL(string: endpoint) else {
            throw UsageQuotaError.invalidURL
        }

        let payload: [String: Any] = [
            "user_key": userKey,
            "seconds": seconds,
            "plan": plan,
            "recorded_at": recordedAt.timeIntervalSince1970
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            throw UsageQuotaError.invalidResponse(statusCode: 0, body: "Failed to serialize request")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = analyticsToken {
            request.setValue(token, forHTTPHeaderField: "x-analytics-token")
        }
        request.httpBody = jsonData
        request.timeoutInterval = timeout

        let startTime = Date()
        print("📤 UsageQuotaClient: [bookUsage] Request to \(endpoint) - user: \(userKey), seconds: \(seconds)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let elapsed = Date().timeIntervalSince(startTime)
            print("📥 UsageQuotaClient: [bookUsage] Response received in \(String(format: "%.2f", elapsed))s")

            guard let httpResponse = response as? HTTPURLResponse else {
                throw UsageQuotaError.invalidResponse(statusCode: 0, body: "Not HTTP response")
            }

            guard httpResponse.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("❌ UsageQuotaClient: [bookUsage] Error \(httpResponse.statusCode): \(body)")
                throw UsageQuotaError.invalidResponse(statusCode: httpResponse.statusCode, body: body)
            }

            print("✅ UsageQuotaClient: [bookUsage] Success - booked \(seconds)s for user \(userKey)")
        } catch let error as UsageQuotaError {
            throw error
        } catch {
            throw UsageQuotaError.networkError(error)
        }
    }
}
