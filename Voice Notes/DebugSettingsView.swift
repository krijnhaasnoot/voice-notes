import SwiftUI

struct DebugSettingsView: View {
    @ObservedObject var recordingsManager: RecordingsManager
    @ObservedObject private var usageVM = UsageViewModel.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    // Debug master toggle
    @AppStorage("debug_modeEnabled") private var debugModeEnabled: Bool = false

    // Debug simulation states
    @AppStorage("debug_subscriptionOverride") private var debugSubscriptionOverride: String = "none"
    @AppStorage("debug_usageOverride") private var debugUsageOverride: Bool = false
    @AppStorage("debug_usageSeconds") private var debugUsageSeconds: Int = 0
    @AppStorage("debug_limitSeconds") private var debugLimitSeconds: Int = 1800

    @State private var showingResetConfirm = false
    @State private var showingToast = false
    @State private var toastMessage = ""
    @Environment(\.dismiss) private var dismiss

    // Computed property to check if any debug setting is active
    private var hasActiveDebugSettings: Bool {
        debugSubscriptionOverride != "none" || debugUsageOverride || usageVM.isDebugOverrideActive
    }

    var body: some View {
        NavigationStack {
            Form {
                // Header with Master Toggle
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "ladybug.fill")
                                .font(.title)
                                .foregroundStyle(.red)
                            Text("Debug Mode")
                                .font(.poppins.title2)
                                .fontWeight(.bold)
                        }
                        Text("Simulate different subscription and usage scenarios for testing")
                            .font(.poppins.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)

                    // Master toggle
                    Toggle(isOn: $debugModeEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enable Debug Mode")
                                .font(.poppins.headline)
                            if debugModeEnabled && hasActiveDebugSettings {
                                Text("Active overrides detected")
                                    .font(.poppins.caption)
                                    .foregroundStyle(.orange)
                            } else if debugModeEnabled {
                                Text("Debug controls enabled")
                                    .font(.poppins.caption)
                                    .foregroundStyle(.green)
                            } else {
                                Text("Using real data")
                                    .font(.poppins.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onChange(of: debugModeEnabled) { _, isEnabled in
                        if !isEnabled {
                            // When disabling debug mode, clear active overrides but keep settings
                            // This allows settings to persist when debug mode is re-enabled
                            usageVM.clearDebugOverride()
                            subscriptionManager.objectWillChange.send()
                            showToast(message: "Debug mode disabled - using real data")
                        } else {
                            // When re-enabling, reapply any previously saved debug settings
                            if debugSubscriptionOverride != "none" {
                                subscriptionManager.objectWillChange.send()
                                let currentUsage = debugUsageOverride ? debugUsageSeconds : usageVM.secondsUsed
                                let newLimit = limitForPlan(debugSubscriptionOverride)
                                usageVM.applyDebugOverride(
                                    secondsUsed: currentUsage,
                                    limitSeconds: newLimit,
                                    plan: debugSubscriptionOverride
                                )
                                showToast(message: "Debug mode enabled - restored previous settings")
                            } else {
                                showToast(message: "Debug mode enabled")
                            }
                        }
                    }
                }

                // Only show debug controls if debug mode is enabled
                if debugModeEnabled {
                    // Subscription Simulation
                    Section(header: Text("Subscription Simulation")) {
                    Picker("Simulated Plan", selection: $debugSubscriptionOverride) {
                        Text("None (Use Real)").tag("none")
                        Text("Free Trial").tag("free")
                        Text("Echo Standard").tag("standard")
                        Text("Echo Premium").tag("premium")
                        Text("Own Key").tag("own_key")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: debugSubscriptionOverride) { _, newValue in
                        // Notify SubscriptionManager to update UI
                        subscriptionManager.objectWillChange.send()

                        // Update usage limits to match new plan
                        if newValue != "none" {
                            let newLimit = limitForPlan(newValue)
                            debugLimitSeconds = newLimit

                            // Use the debug slider value if override is active, otherwise use current real usage
                            let currentUsage = debugUsageOverride ? debugUsageSeconds : usageVM.secondsUsed

                            // ALWAYS update UsageViewModel with new plan limits
                            usageVM.applyDebugOverride(
                                secondsUsed: currentUsage,
                                limitSeconds: newLimit,
                                plan: newValue
                            )

                            showToast(message: "Applied: \(planDisplayName(newValue)) - \(currentUsage/60)/\(newLimit/60) min")
                        } else {
                            // Reset to real data
                            usageVM.clearDebugOverride()
                            showToast(message: "Using real subscription data")
                        }
                    }

                    if debugSubscriptionOverride != "none" {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Override Active")
                                    .font(.poppins.subheadline)
                                    .fontWeight(.semibold)
                                Text("App will behave as if you have \(planDisplayName(debugSubscriptionOverride))")
                                    .font(.poppins.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Usage Quota Simulation
                Section(header: Text("Usage Quota Simulation")) {
                    Toggle("Override Usage Data", isOn: $debugUsageOverride)
                        .font(.poppins.headline)
                        .onChange(of: debugUsageOverride) { _, isEnabled in
                            if isEnabled {
                                // When enabling override, sync the limit with the current subscription
                                if debugSubscriptionOverride != "none" {
                                    debugLimitSeconds = limitForPlan(debugSubscriptionOverride)
                                }
                            }
                        }

                    if debugUsageOverride {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Seconds Used: \(debugUsageSeconds)s (\(debugUsageSeconds / 60) min)")
                                    .font(.poppins.caption)
                                    .foregroundStyle(.secondary)

                                Slider(value: Binding(
                                    get: { Double(debugUsageSeconds) },
                                    set: { debugUsageSeconds = Int($0) }
                                ), in: 0...14400, step: 300)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Limit: \(debugLimitSeconds)s (\(debugLimitSeconds / 60) min)")
                                    .font(.poppins.caption)
                                    .foregroundStyle(.secondary)

                                Slider(value: Binding(
                                    get: { Double(debugLimitSeconds) },
                                    set: { debugLimitSeconds = Int($0) }
                                ), in: 0...14400, step: 300)
                            }

                            // Progress preview
                            VStack(spacing: 8) {
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 12)

                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(debugUsageSeconds > debugLimitSeconds ? Color.red : Color.green)
                                            .frame(width: geometry.size.width * min(Double(debugUsageSeconds) / Double(max(debugLimitSeconds, 1)), 1.0), height: 12)
                                    }
                                }
                                .frame(height: 12)

                                HStack {
                                    Text("\(max(0, (debugLimitSeconds - debugUsageSeconds) / 60)) min remaining")
                                        .font(.poppins.caption)
                                        .foregroundStyle(debugUsageSeconds > debugLimitSeconds ? .red : .secondary)
                                    Spacer()
                                }
                            }
                        }
                        .padding(.vertical, 8)

                        Button {
                            // Use the subscription plan if selected, otherwise use current plan
                            let plan = debugSubscriptionOverride != "none" ? debugSubscriptionOverride : usageVM.currentPlan

                            // Apply the override
                            usageVM.applyDebugOverride(
                                secondsUsed: debugUsageSeconds,
                                limitSeconds: debugLimitSeconds,
                                plan: plan
                            )

                            // Show toast confirmation
                            let usedMinutes = debugUsageSeconds / 60
                            let limitMinutes = debugLimitSeconds / 60
                            toastMessage = "Applied: \(usedMinutes)/\(limitMinutes) min"
                            showingToast = true

                            // Auto-dismiss toast after 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showingToast = false
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Apply to App")
                            }
                            .font(.poppins.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Quick Scenarios
                Section(header: Text("Quick Test Scenarios")) {
                    VStack(spacing: 12) {
                        QuickScenarioButton(
                            title: "New Free User",
                            description: "0/30 min used",
                            icon: "person.badge.plus",
                            color: .green
                        ) {
                            debugSubscriptionOverride = "free"
                            debugUsageOverride = true
                            debugUsageSeconds = 0
                            debugLimitSeconds = 1800
                            usageVM.applyDebugOverride(secondsUsed: 0, limitSeconds: 1800, plan: "free")
                            showToast(message: "Applied: New Free User (0/30 min)")
                        }

                        QuickScenarioButton(
                            title: "Almost Out (Free)",
                            description: "28/30 min used",
                            icon: "exclamationmark.triangle",
                            color: .orange
                        ) {
                            debugSubscriptionOverride = "free"
                            debugUsageOverride = true
                            debugUsageSeconds = 1680
                            debugLimitSeconds = 1800
                            usageVM.applyDebugOverride(secondsUsed: 1680, limitSeconds: 1800, plan: "free")
                            showToast(message: "Applied: Almost Out (28/30 min)")
                        }

                        QuickScenarioButton(
                            title: "Out of Minutes",
                            description: "30/30 min used",
                            icon: "xmark.circle",
                            color: .red
                        ) {
                            debugSubscriptionOverride = "free"
                            debugUsageOverride = true
                            debugUsageSeconds = 1800
                            debugLimitSeconds = 1800
                            usageVM.applyDebugOverride(secondsUsed: 1800, limitSeconds: 1800, plan: "free")
                            showToast(message: "Applied: Out of Minutes (30/30 min)")
                        }

                        QuickScenarioButton(
                            title: "Standard User (Plenty Left)",
                            description: "20/120 min used",
                            icon: "checkmark.circle",
                            color: .blue
                        ) {
                            debugSubscriptionOverride = "standard"
                            debugUsageOverride = true
                            debugUsageSeconds = 1200
                            debugLimitSeconds = 7200
                            usageVM.applyDebugOverride(secondsUsed: 1200, limitSeconds: 7200, plan: "standard")
                            showToast(message: "Applied: Standard (20/120 min)")
                        }

                        QuickScenarioButton(
                            title: "With Top-Up (180 min total)",
                            description: "50/180 min used (120 sub + 60 topup)",
                            icon: "plus.circle",
                            color: .purple
                        ) {
                            debugSubscriptionOverride = "standard"
                            debugUsageOverride = true
                            debugUsageSeconds = 3000
                            debugLimitSeconds = 10800
                            usageVM.applyDebugOverride(secondsUsed: 3000, limitSeconds: 10800, plan: "standard")
                            showToast(message: "Applied: With Top-Up (50/180 min)")
                        }
                    }
                }

                // Reset
                Section {
                    Button(role: .destructive) {
                        showingResetConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset All Debug Overrides")
                        }
                        .font(.poppins.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                    }
                }
                } // End if debugModeEnabled

                // Real Analytics Access (always visible)
                Section(header: Text("Analytics")) {
                    NavigationLink(destination: TelemetryView(recordingsManager: recordingsManager)) {
                        HStack {
                            Image(systemName: "chart.bar.xaxis")
                                .foregroundStyle(.blue)
                            Text("View Analytics")
                                .font(.poppins.body)
                        }
                    }
                }
            }
            .navigationTitle("Debug & Analytics")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Load real usage data when view appears (if not already overridden)
                if !usageVM.isDebugOverrideActive {
                    Task {
                        await usageVM.refresh()

                        // Sync debug sliders with real data after refresh
                        await MainActor.run {
                            if !debugUsageOverride {
                                debugUsageSeconds = usageVM.secondsUsed
                                debugLimitSeconds = usageVM.limitSeconds
                            }
                        }
                    }
                } else {
                    // Already in debug mode, sync sliders with current debug values
                    debugUsageSeconds = usageVM.secondsUsed
                    debugLimitSeconds = usageVM.limitSeconds
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay(
                Group {
                    if showingToast {
                        VStack {
                            Spacer()
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(toastMessage)
                                    .font(.poppins.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                            )
                            .padding(.bottom, 100)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingToast)
                    }
                }
            )
            .confirmationDialog(
                "Reset Debug Settings?",
                isPresented: $showingResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset to Real Data", role: .destructive) {
                    debugSubscriptionOverride = "none"
                    debugUsageOverride = false
                    debugUsageSeconds = 0
                    debugLimitSeconds = 1800
                    usageVM.clearDebugOverride()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will disable all debug overrides and use real subscription and usage data.")
            }
        }
    }

    private func planDisplayName(_ key: String) -> String {
        switch key {
        case "free": return "Free Trial"
        case "standard": return "Echo Standard"
        case "premium": return "Echo Premium"
        case "own_key": return "Own Key Plan"
        default: return "Unknown"
        }
    }

    private func showToast(message: String) {
        toastMessage = message
        showingToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showingToast = false
        }
    }

    private func limitForPlan(_ plan: String) -> Int {
        switch plan {
        case "free":
            return 1800 // 30 minutes
        case "standard":
            return 7200 // 120 minutes
        case "premium":
            return 36000 // 600 minutes
        case "own_key":
            return 600000 // 10000 minutes
        default:
            return 1800
        }
    }
}

struct QuickScenarioButton: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.poppins.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.poppins.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .foregroundStyle(color)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(color.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// Extension to UsageViewModel for debug overrides
extension UsageViewModel {
    func applyDebugOverride(secondsUsed: Int, limitSeconds: Int, plan: String? = nil) {
        Task { @MainActor in
            self.isDebugOverrideActive = true
            self.secondsUsed = secondsUsed
            self.limitSeconds = limitSeconds
            self.remainingSeconds = max(limitSeconds - secondsUsed, 0)
            if let plan = plan {
                self.currentPlan = plan
            }
            self.isLoading = false
            // Force UI update
            self.objectWillChange.send()
            print("🐛 Debug: Applied usage override - \(secondsUsed)s used / \(limitSeconds)s limit (\(limitSeconds/60) min), plan: \(plan ?? "unchanged")")
        }
    }

    func clearDebugOverride() {
        Task { @MainActor in
            self.isDebugOverrideActive = false
            await refresh()
            self.objectWillChange.send()
            print("🐛 Debug: Cleared debug override, refreshing real data")
        }
    }
}
