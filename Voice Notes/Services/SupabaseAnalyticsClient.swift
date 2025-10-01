//
//  SupabaseAnalyticsClient.swift
//  Voice Notes
//
//  Production-safe Supabase REST API client for global analytics
//

import Foundation

/// Lightweight client for fetching aggregated analytics from Supabase
struct SupabaseAnalyticsClient {

    // MARK: - Types

    struct GroupCount: Hashable, Codable {
        let key: String
        let count: Int
    }

    struct DailyPoint: Hashable, Codable {
        let date: Date
        let count: Int
    }

    enum ClientError: Error, LocalizedError {
        case missingAnonKey
        case invalidURL
        case networkError(Error)
        case decodingError(Error)
        case httpError(statusCode: Int, message: String)
        case timeout

        var errorDescription: String? {
            switch self {
            case .missingAnonKey: return "Supabase anon key not found in Info.plist"
            case .invalidURL: return "Invalid API URL"
            case .networkError(let err): return "Network error: \(err.localizedDescription)"
            case .decodingError(let err): return "JSON decoding error: \(err.localizedDescription)"
            case .httpError(let code, let msg): return "HTTP \(code): \(msg)"
            case .timeout: return "Request timeout"
            }
        }
    }

    // MARK: - Configuration

    private let baseURL = "https://rhfhateyqdiysgooiqtd.supabase.co/rest/v1"
    private let anonKeyProvider: () -> String?
    private let timeout: TimeInterval = 8.0
    private let maxPaginationLimit = 50_000

    // MARK: - Init

    init(anonKeyProvider: @escaping () -> String? = {
        Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String
    }) {
        self.anonKeyProvider = anonKeyProvider
    }

    // MARK: - Public API

    /// Total event count since a given date
    func totalEvents(since: Date) async throws -> Int {
        let sinceISO = isoString(from: since)
        let urlString = "\(baseURL)/analytics_events?select=id&created_at=gte.\(sinceISO)"
        return try await paginatedCount(urlString: urlString)
    }

    /// Distinct user count since a given date
    func distinctUsers(since: Date) async throws -> Int {
        let sinceISO = isoString(from: since)
        // Use distinct on user_id
        let urlString = "\(baseURL)/analytics_events?select=user_id&user_id=not.is.null&created_at=gte.\(sinceISO)"

        // Fetch all user_ids with pagination, then count unique
        var allUserIds = Set<String>()
        var offset = 0
        let limit = 1000

        while offset < maxPaginationLimit {
            let pagedURL = "\(urlString)&limit=\(limit)&offset=\(offset)"
            let rows: [[String: String]] = try await fetchJSON(urlString: pagedURL)

            if rows.isEmpty { break }

            for row in rows {
                if let userId = row["user_id"], !userId.isEmpty {
                    allUserIds.insert(userId)
                }
            }

            if rows.count < limit { break }
            offset += limit
        }

        return allUserIds.count
    }

    /// Top N events by count
    func topEvents(since: Date, limit: Int) async throws -> [GroupCount] {
        let sinceISO = isoString(from: since)
        let urlString = "\(baseURL)/analytics_events?select=event_name&created_at=gte.\(sinceISO)"

        // Fetch all event names with pagination
        var eventCounts: [String: Int] = [:]
        var offset = 0
        let pageLimit = 1000

        while offset < maxPaginationLimit {
            let pagedURL = "\(urlString)&limit=\(pageLimit)&offset=\(offset)"
            let rows: [[String: String]] = try await fetchJSON(urlString: pagedURL)

            if rows.isEmpty { break }

            for row in rows {
                if let eventName = row["event_name"], !eventName.isEmpty {
                    eventCounts[eventName, default: 0] += 1
                }
            }

            if rows.count < pageLimit { break }
            offset += pageLimit
        }

        // Sort and take top N
        return eventCounts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { GroupCount(key: $0.key, count: $0.value) }
    }

    /// Platform distribution
    func platformDistribution(since: Date) async throws -> [GroupCount] {
        let sinceISO = isoString(from: since)
        let urlString = "\(baseURL)/analytics_events?select=platform&created_at=gte.\(sinceISO)"

        var platformCounts: [String: Int] = [:]
        var offset = 0
        let pageLimit = 1000

        while offset < maxPaginationLimit {
            let pagedURL = "\(urlString)&limit=\(pageLimit)&offset=\(offset)"
            let rows: [[String: String]] = try await fetchJSON(urlString: pagedURL)

            if rows.isEmpty { break }

            for row in rows {
                if let platform = row["platform"], !platform.isEmpty {
                    platformCounts[platform, default: 0] += 1
                }
            }

            if rows.count < pageLimit { break }
            offset += pageLimit
        }

        return platformCounts
            .sorted { $0.value > $1.value }
            .map { GroupCount(key: $0.key, count: $0.value) }
    }

    /// Daily time series (last N days)
    func dailySeries(since days: Int) async throws -> [DailyPoint] {
        let now = Date()
        let sinceDate = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
        let sinceISO = isoString(from: sinceDate)
        let urlString = "\(baseURL)/analytics_events?select=created_at&created_at=gte.\(sinceISO)"

        var dailyCounts: [String: Int] = [:]
        var offset = 0
        let pageLimit = 1000

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        while offset < maxPaginationLimit {
            let pagedURL = "\(urlString)&limit=\(pageLimit)&offset=\(offset)"
            let rows: [[String: String]] = try await fetchJSON(urlString: pagedURL)

            if rows.isEmpty { break }

            for row in rows {
                if let createdAt = row["created_at"], let date = parseISO8601(createdAt) {
                    let dayKey = dateFormatter.string(from: date)
                    dailyCounts[dayKey, default: 0] += 1
                }
            }

            if rows.count < pageLimit { break }
            offset += pageLimit
        }

        // Convert to DailyPoint array, sorted by date
        return dailyCounts.compactMap { key, count -> DailyPoint? in
            guard let date = dateFormatter.date(from: key) else { return nil }
            return DailyPoint(date: date, count: count)
        }.sorted { $0.date < $1.date }
    }

    /// Feedback split (thumbs up vs down)
    func feedbackSplit(since: Date) async throws -> (thumbsUp: Int, thumbsDown: Int) {
        let sinceISO = isoString(from: since)
        let urlString = "\(baseURL)/analytics_events?select=properties&event_name=eq.summary_feedback_submitted&created_at=gte.\(sinceISO)"

        var thumbsUp = 0
        var thumbsDown = 0
        var offset = 0
        let pageLimit = 1000

        while offset < maxPaginationLimit {
            let pagedURL = "\(urlString)&limit=\(pageLimit)&offset=\(offset)"

            // Fetch as raw JSON to parse properties
            guard let url = URL(string: pagedURL),
                  let anonKey = anonKeyProvider() else {
                throw ClientError.invalidURL
            }

            var request = URLRequest(url: url, timeoutInterval: timeout)
            request.addValue(anonKey, forHTTPHeaderField: "apikey")
            request.addValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)
            try validateResponse(response, data: data)

            let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
            if rows.isEmpty { break }

            for row in rows {
                if let properties = row["properties"] as? [String: Any],
                   let feedbackType = properties["feedback_type"] as? String {
                    if feedbackType == "thumbs_up" {
                        thumbsUp += 1
                    } else if feedbackType == "thumbs_down" {
                        thumbsDown += 1
                    }
                }
            }

            if rows.count < pageLimit { break }
            offset += pageLimit
        }

        return (thumbsUp, thumbsDown)
    }

    // MARK: - Private Helpers

    private struct GenericRow: Codable {}

    private func paginatedCount(urlString: String) async throws -> Int {
        var total = 0
        var offset = 0
        let limit = 1000

        while offset < maxPaginationLimit {
            let pagedURL = "\(urlString)&limit=\(limit)&offset=\(offset)"
            let rows: [GenericRow] = try await fetchJSON(urlString: pagedURL)

            if rows.isEmpty { break }

            total += rows.count

            if rows.count < limit { break }
            offset += limit
        }

        return total
    }

    private func fetchJSON<T: Decodable>(urlString: String) async throws -> T {
        guard let url = URL(string: urlString),
              let anonKey = anonKeyProvider() else {
            throw ClientError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.addValue(anonKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("count=exact", forHTTPHeaderField: "Prefer")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateResponse(response, data: data)

            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch let error as ClientError {
            throw error
        } catch let error as DecodingError {
            throw ClientError.decodingError(error)
        } catch {
            throw ClientError.networkError(error)
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.networkError(NSError(domain: "InvalidResponse", code: -1))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClientError.httpError(statusCode: httpResponse.statusCode, message: message)
        }
    }

    private func isoString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }
        // Fallback without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
