import SwiftUI

struct MinutesMeterView: View {
    @ObservedObject private var minutesTracker = MinutesTracker.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingPaywall = false

    var compact: Bool = false

    var body: some View {
        Group {
            if compact {
                compactView
            } else {
                fullView
            }
        }
        .id(minutesTracker.minutesUsed) // Force re-render when minutes change
    }

    private var compactView: some View {
        HStack(spacing: 8) {
            Image(systemName: minutesTracker.isAtLimit ? "exclamationmark.circle.fill" : "clock.fill")
                .foregroundColor(meterColor)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                if minutesTracker.isFreeTier {
                    Text("\(minutesTracker.formattedMinutesRemaining) trial")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(meterColor)
                } else {
                    Text("\(minutesTracker.formattedMinutesRemaining) left")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(meterColor)
                }

                ProgressView(value: 1 - minutesTracker.usagePercentage)
                    .tint(meterColor)
                    .frame(height: 4)
            }

            if minutesTracker.isAtLimit || minutesTracker.isNearLimit {
                Button(action: { showingPaywall = true }) {
                    Text("Upgrade")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .cornerRadius(6)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(meterColor.opacity(0.1))
        .cornerRadius(10)
        .sheet(isPresented: $showingPaywall) {
            PaywallView(canDismiss: true)
        }
    }

    private var fullView: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(minutesTracker.currentTierName)
                        .font(.headline)
                        .fontWeight(.bold)

                    if minutesTracker.isFreeTier {
                        Text("\(minutesTracker.monthlyLimit) minutes total")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(minutesTracker.monthlyLimit) minutes per month")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if minutesTracker.isFreeTier {
                    Button(action: { showingPaywall = true }) {
                        Text("Upgrade")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
            }

            VStack(spacing: 8) {
                HStack {
                    Text(minutesTracker.isFreeTier ? "Minutes left in trial" : "Usage this month")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    if minutesTracker.isFreeTier {
                        Text("\(minutesTracker.formattedMinutesRemaining) remaining")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(meterColor)
                    } else {
                        Text("\(minutesTracker.formattedMinutesUsed) / \(minutesTracker.monthlyLimit) min")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(meterColor)
                    }
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 12)

                        // Progress
                        RoundedRectangle(cornerRadius: 8)
                            .fill(meterGradient)
                            .frame(width: geometry.size.width * minutesTracker.usagePercentage, height: 12)
                            .animation(.spring(), value: minutesTracker.usagePercentage)
                    }
                }
                .frame(height: 12)

                HStack {
                    if minutesTracker.isAtLimit {
                        Label("Limit reached", systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else if minutesTracker.isNearLimit {
                        Label("Running low", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Text("\(minutesTracker.formattedMinutesRemaining) remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if !minutesTracker.isFreeTier {
                        Text("Resets in \(minutesTracker.daysUntilReset)d")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Own Key without API key warning
            if subscriptionManager.isOwnKeySubscriber && !subscriptionManager.hasApiKeyConfigured {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.orange)
                            .font(.title2)

                        Text("API Key Required")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }

                    Text("Add your API key in AI Provider Settings to start recording")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    NavigationLink(destination: AIProviderSettingsView()) {
                        Text("Open AI Provider Settings")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            } else if minutesTracker.isAtLimit {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)

                        Text("You've used all your minutes for this month")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }

                    Button(action: { showingPaywall = true }) {
                        Text("Upgrade to Continue Recording")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .sheet(isPresented: $showingPaywall) {
            PaywallView(canDismiss: true)
        }
    }

    private var meterColor: Color {
        if minutesTracker.isAtLimit {
            return .red
        } else if minutesTracker.isNearLimit {
            return .orange
        } else {
            return .green
        }
    }

    private var meterGradient: LinearGradient {
        if minutesTracker.isAtLimit {
            return LinearGradient(
                colors: [.red, .red.opacity(0.7)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if minutesTracker.isNearLimit {
            return LinearGradient(
                colors: [.orange, .yellow],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [.green, .blue],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        MinutesMeterView(compact: true)
            .padding()

        MinutesMeterView(compact: false)
            .padding()
    }
}
