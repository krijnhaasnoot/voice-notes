import SwiftUI

struct HelpSupportView: View {
    @AppStorage("analyticsPIN") private var analyticsPIN: String = ""
    @State private var showAnalytics = false
    @State private var showResetPinConfirm = false

    var body: some View {
        Form {
            // Feedback & Support
            Section(header: Text(NSLocalizedString("settings.feedback_support", comment: "Feedback & Support"))) {
                Button(action: { sendFeedback() }) {
                    HStack(spacing: 12) {
                        Image(systemName: "message.fill")
                            .font(.poppins.regular(size: 20))
                            .foregroundColor(.green)
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("settings.send_feedback", comment: "Send Feedback via WhatsApp"))
                                .font(.poppins.body)
                                .foregroundColor(.primary)

                            Text(NSLocalizedString("settings.send_feedback_desc", comment: "Report issues or request features"))
                                .font(.poppins.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right.square")
                            .font(.poppins.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }

            // Privacy & Data Usage
            Section(header: Text(NSLocalizedString("settings.privacy_data_usage", comment: "Privacy & Data Usage"))) {
                NavigationLink(destination: PrivacyInfoView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield")
                            .font(.poppins.regular(size: 20))
                            .foregroundColor(.blue)
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("settings.privacy_data_usage", comment: "Privacy & Data Usage"))
                                .font(.poppins.body)
                                .foregroundColor(.primary)

                            Text(PrivacyStrings.shortDescription)
                                .font(.poppins.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                }
                .padding(.vertical, 4)

                Button(role: .destructive) {
                    showResetPinConfirm = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "key.fill")
                            .font(.poppins.regular(size: 20))
                            .foregroundColor(.red)
                            .frame(width: 28, height: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("settings.reset_analytics_pin", comment: "Reset Analytics PIN"))
                                .font(.poppins.body)
                                .foregroundColor(.primary)
                            Text(NSLocalizedString("settings.reset_pin_desc", comment: "Remove the PIN required to open Analytics"))
                                .font(.poppins.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(NSLocalizedString("settings.help_support", comment: "Help & Support"))
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            NSLocalizedString("settings.reset_analytics_pin", comment: "Reset Analytics PIN") + "?",
            isPresented: $showResetPinConfirm,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("settings.reset_analytics_pin", comment: "Reset PIN"), role: .destructive) {
                analyticsPIN = ""
            }
            Button(NSLocalizedString("alert.cancel", comment: "Cancel"), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("settings.reset_pin_message", comment: "Reset PIN message"))
        }
    }

    private func sendFeedback() {
        let phoneNumber = "+31685554138"
        let message = "Hi! I have feedback about Voice Notes:"

        if let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://wa.me/\(phoneNumber)?text=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }
}
