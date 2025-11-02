import Foundation

// Simple API client for usage tracking
struct UsageAPI {
    let base: String
    let token: String

    init() {
        guard let baseURL = Bundle.main.object(forInfoDictionaryKey: "INGEST_URL") as? String,
              let authToken = Bundle.main.object(forInfoDictionaryKey: "ANALYTICS_TOKEN") as? String else {
            fatalError("INGEST_URL or ANALYTICS_TOKEN not configured in Info.plist")
        }
        self.base = baseURL
        self.token = authToken
    }

    func post(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: base + path) else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue(token, forHTTPHeaderField: "x-analytics-token")
        req.timeoutInterval = 30

        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ UsageAPI: Failed to serialize JSON body:", error)
            throw error
        }

        print("📤 UsageAPI: POST \(path)")
        print("📤 Body:", body)

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            print("❌ UsageAPI: Invalid response type")
            throw URLError(.badServerResponse)
        }

        print("📥 UsageAPI: Status \(http.statusCode)")

        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? "<no body>"
            print("❌ UsageAPI: HTTP \(http.statusCode) - \(text)")
            throw NSError(
                domain: "UsageAPI",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(text)"]
            )
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let text = String(data: data, encoding: .utf8) ?? "<binary>"
            print("❌ UsageAPI: Failed to parse JSON - \(text)")
            throw NSError(
                domain: "UsageAPI",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON response"]
            )
        }

        print("✅ UsageAPI: Success - \(json)")
        return json
    }
}

// MARK: - UsageQuotaClient Singleton

/// Singleton client for crediting usage top-ups to the backend
/// Used by TopUpManager to process consumable in-app purchases
@MainActor
final class UsageQuotaClient {
    static let shared = UsageQuotaClient()
    private let api = UsageAPI()
    private init() {}

    /// Credits a usage top-up to the backend
    /// - Parameters:
    ///   - userKey: String identifying the user
    ///   - seconds: Number of seconds to credit
    ///   - transactionID: Associated StoreKit transaction ID
    ///   - pricePaid: Price paid for the top-up (optional)
    ///   - currency: Currency identifier (optional)
    ///
    /// Throws on request or network error
    func creditTopUp(userKey: String, seconds: Int, transactionID: String, pricePaid: Decimal?, currency: String?) async throws {
        var body: [String: Any] = [
            "user_key": userKey,
            "seconds": seconds,
            "transaction_id": transactionID
        ]
        if let price = pricePaid {
            body["price_paid"] = price
        }
        if let currency = currency {
            body["currency"] = currency
        }

        // The API path should match what is expected for top-up events
        let _ = try await api.post("/ingest/usage/topup", body: body)
    }
}
