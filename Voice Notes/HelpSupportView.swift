import SwiftUI

struct HelpSupportView: View {
    @AppStorage("analyticsPIN") private var analyticsPIN: String = ""
    @State private var showAnalytics = false
    @State private var showResetPinConfirm = false

    var body: some View {
        Form {
            // Feedback & Support
            Section(header: Text("Feedback & Support")) {
                Button(action: { sendFeedback() }) {
                    HStack(spacing: 12) {
                        Image(systemName: "message.fill")
                            .font(.poppins.regular(size: 20))
                            .foregroundColor(.green)
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Send Feedback via WhatsApp")
                                .font(.poppins.body)
                                .foregroundColor(.primary)

                            Text("Report issues or request features")
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
            Section(header: Text("Privacy & Data Usage")) {
                NavigationLink(destination: PrivacyInfoView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield")
                            .font(.poppins.regular(size: 20))
                            .foregroundColor(.blue)
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Privacy & Data Usage")
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
                            Text("Reset Analytics PIN")
                                .font(.poppins.body)
                                .foregroundColor(.primary)
                            Text("Remove the PIN required to open Analytics")
                                .font(.poppins.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            "Reset Analytics PIN?",
            isPresented: $showResetPinConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset PIN", role: .destructive) {
                analyticsPIN = ""
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will need to create a new PIN the next time you access Analytics.")
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
