//
//  SupabaseAnalyticsSmokeTest.swift
//  Voice Notes
//
//  Smoke test for Supabase Analytics Integration
//  Add a debug button in your app to call runSmokeTest()
//

import Foundation

#if DEBUG
/// Smoke test for Supabase Analytics Client
struct SupabaseAnalyticsSmokeTest {

    /// Run comprehensive smoke test
    /// Call this from a debug button or SwiftUI preview
    static func runSmokeTest() async {
        print("\n🧪 ===== SUPABASE ANALYTICS SMOKE TEST =====")
        print("Testing connection to: https://rhfhateyqdiysgooiqtd.supabase.co")
        print("")

        let client = SupabaseAnalyticsClient()
        let now = Date()
        guard let since30d = Calendar.current.date(byAdding: .day, value: -30, to: now) else {
            print("❌ Failed to calculate date range")
            return
        }

        // Test 1: Total Events
        print("1️⃣  Testing totalEvents(since: 30 days ago)...")
        do {
            let total = try await client.totalEvents(since: since30d)
            print("   ✅ SUCCESS: \(total) total events")
        } catch {
            print("   ❌ FAILED: \(error.localizedDescription)")
        }

        // Test 2: Distinct Users
        print("\n2️⃣  Testing distinctUsers(since: 30 days ago)...")
        do {
            let users = try await client.distinctUsers(since: since30d)
            print("   ✅ SUCCESS: \(users) distinct users")
        } catch {
            print("   ❌ FAILED: \(error.localizedDescription)")
        }

        // Test 3: Top Events
        print("\n3️⃣  Testing topEvents(since: 30 days ago, limit: 5)...")
        do {
            let events = try await client.topEvents(since: since30d, limit: 5)
            print("   ✅ SUCCESS: \(events.count) events")
            for (idx, event) in events.enumerated() {
                print("      \(idx + 1). \(event.key): \(event.count)")
            }
        } catch {
            print("   ❌ FAILED: \(error.localizedDescription)")
        }

        // Test 4: Platform Distribution
        print("\n4️⃣  Testing platformDistribution(since: 30 days ago)...")
        do {
            let platforms = try await client.platformDistribution(since: since30d)
            print("   ✅ SUCCESS: \(platforms.count) platforms")
            for platform in platforms {
                print("      - \(platform.key): \(platform.count)")
            }
        } catch {
            print("   ❌ FAILED: \(error.localizedDescription)")
        }

        // Test 5: Daily Series
        print("\n5️⃣  Testing dailySeries(since: 14 days)...")
        do {
            let series = try await client.dailySeries(since: 14)
            print("   ✅ SUCCESS: \(series.count) data points")
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM dd"
            for point in series.prefix(5) {
                print("      - \(dateFormatter.string(from: point.date)): \(point.count)")
            }
            if series.count > 5 {
                print("      ... (\(series.count - 5) more)")
            }
        } catch {
            print("   ❌ FAILED: \(error.localizedDescription)")
        }

        // Test 6: Feedback Split
        print("\n6️⃣  Testing feedbackSplit(since: 30 days ago)...")
        do {
            let feedback = try await client.feedbackSplit(since: since30d)
            print("   ✅ SUCCESS: 👍 \(feedback.thumbsUp) / 👎 \(feedback.thumbsDown)")
        } catch {
            print("   ❌ FAILED: \(error.localizedDescription)")
        }

        // Test 7: Full Service Integration
        print("\n7️⃣  Testing AggregatedAnalyticsService integration...")
        await MainActor.run {
            Task {
                await AggregatedAnalyticsService.shared.fetchAggregatedMetrics()
                if let metrics = AggregatedAnalyticsService.shared.aggregatedMetrics {
                    print("   ✅ SUCCESS: Service fetched metrics")
                    print("      - Total Users: \(metrics.totalUsers)")
                    print("      - Total Events: \(metrics.totalRecordings)")
                    print("      - Platforms: \(metrics.platformDistribution)")
                    print("      - Using Fallback: \(AggregatedAnalyticsService.shared.isUsingFallback)")
                } else {
                    print("   ⚠️  WARNING: No metrics returned")
                }
            }
        }

        print("\n✅ ===== SMOKE TEST COMPLETE =====\n")
    }

    /// Quick test - just check connection works
    static func quickTest() async -> Bool {
        let client = SupabaseAnalyticsClient()
        let now = Date()
        guard let since30d = Calendar.current.date(byAdding: .day, value: -30, to: now) else {
            return false
        }

        do {
            let total = try await client.totalEvents(since: since30d)
            print("✅ Supabase Analytics: \(total) events in last 30 days")
            return true
        } catch {
            print("❌ Supabase Analytics failed: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Debug Button View

import SwiftUI

/// Add this view to your settings or debug menu
struct SupabaseAnalyticsDebugView: View {
    @State private var isRunning = false
    @State private var testResult: String = "Tap 'Run Test' to start"

    var body: some View {
        VStack(spacing: 20) {
            Text("🧪 Supabase Analytics Test")
                .font(.headline)

            if isRunning {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Running tests...")
                    .foregroundColor(.secondary)
            } else {
                Button("Run Smoke Test") {
                    runTest()
                }
                .buttonStyle(.borderedProminent)
            }

            ScrollView {
                Text(testResult)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
        .padding()
        .navigationTitle("Analytics Debug")
    }

    private func runTest() {
        isRunning = true
        testResult = "Running tests...\n"

        Task {
            // Capture console output
            await SupabaseAnalyticsSmokeTest.runSmokeTest()

            await MainActor.run {
                isRunning = false
                testResult = "Test completed! Check Xcode console for detailed output."
            }
        }
    }
}

#Preview {
    NavigationView {
        SupabaseAnalyticsDebugView()
    }
}
#endif
