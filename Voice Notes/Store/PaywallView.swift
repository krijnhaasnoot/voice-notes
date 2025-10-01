import SwiftUI
import StoreKit

struct PaywallView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var minutesTracker = MinutesTracker.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProduct: EchoProductID = .premium
    @State private var showingError = false
    @State private var isRestoring = false
    @State private var showTrialBanner: Bool = false

    var canDismiss: Bool = false
    var onComplete: (() -> Void)?

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.blue.gradient)

                            Text("Upgrade to Echo")
                                .font(.largeTitle)
                                .fontWeight(.bold)

                            if showTrialBanner {
                                VStack(spacing: 6) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "gift.fill")
                                            .foregroundColor(.green)
                                        Text("60-minute trial started")
                                            .fontWeight(.semibold)
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.green)

                                    Text("Full access to all features")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(10)
                                .transition(.opacity.combined(with: .scale))
                            }

                            Text("Choose the plan that fits your needs")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 20)

                        // Subscription tiers
                        VStack(spacing: 16) {
                            ForEach(EchoProductID.allCases, id: \.self) { productID in
                                SubscriptionCard(
                                    productID: productID,
                                    isSelected: selectedProduct == productID,
                                    price: subscriptionManager.displayPrice(for: productID)
                                ) {
                                    selectedProduct = productID
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Subscribe button
                        Button(action: purchaseSelected) {
                            HStack {
                                if subscriptionManager.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Subscribe to \(selectedProduct.displayName)")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(subscriptionManager.isLoading)
                        .padding(.horizontal)

                        // Restore purchases
                        Button(action: restorePurchases) {
                            HStack {
                                if isRestoring {
                                    ProgressView()
                                        .tint(.blue)
                                } else {
                                    Text("Restore Purchases")
                                        .fontWeight(.medium)
                                }
                            }
                        }
                        .disabled(isRestoring)

                        // Features list
                        VStack(alignment: .leading, spacing: 12) {
                            FeatureRow(icon: "checkmark.circle.fill", text: "AI-powered transcription")
                            FeatureRow(icon: "checkmark.circle.fill", text: "Smart summaries")
                            FeatureRow(icon: "checkmark.circle.fill", text: "Multiple summary modes")
                            FeatureRow(icon: "checkmark.circle.fill", text: "Automatic tagging")
                            FeatureRow(icon: "checkmark.circle.fill", text: "Export & share")
                        }
                        .padding(.horizontal)
                        .padding(.vertical)

                        // Terms
                        Text("Subscriptions auto-renew monthly. Cancel anytime in Settings.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                    }
                }
            }
            .toolbar {
                if canDismiss {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            dismiss()
                            onComplete?()
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(subscriptionManager.purchaseError ?? "An unknown error occurred")
            }
            .onAppear {
                // Capture free tier status on appear to prevent it from disappearing
                showTrialBanner = subscriptionManager.activeSubscription == nil
            }
        }
    }

    private func purchaseSelected() {
        guard let product = subscriptionManager.product(for: selectedProduct) else {
            return
        }

        Task {
            do {
                try await subscriptionManager.purchase(product)
                dismiss()
                onComplete?()
            } catch {
                showingError = true
            }
        }
    }

    private func restorePurchases() {
        isRestoring = true
        Task {
            do {
                try await subscriptionManager.restorePurchases()
                isRestoring = false
                if subscriptionManager.isSubscribed {
                    dismiss()
                    onComplete?()
                }
            } catch {
                isRestoring = false
                subscriptionManager.purchaseError = "Failed to restore purchases"
                showingError = true
            }
        }
    }
}

struct SubscriptionCard: View {
    let productID: EchoProductID
    let isSelected: Bool
    let price: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(productID.displayName)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Text(productID.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(price)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Text("per month")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(productID.features, id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text(feature)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                }

                if productID == .premium {
                    HStack {
                        Spacer()
                        Text("MOST POPULAR")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .font(.body)

            Text(text)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

#Preview {
    PaywallView(canDismiss: true)
}
