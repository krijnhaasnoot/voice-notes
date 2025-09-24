import SwiftUI

struct PrivacyInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Section
                    VStack(spacing: 16) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text(PrivacyStrings.title)
                            .font(.poppins.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    
                    // Body Text Section
                    VStack(alignment: .leading, spacing: 16) {
                        FormattedPrivacyText()
                    }
                    
                    // AI Providers Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Supported AI Providers")
                            .font(.poppins.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            PrivacyProviderRow(
                                provider: .openai,
                                name: "OpenAI (ChatGPT)",
                                description: "Industry-leading language models with strong privacy commitments"
                            )
                            
                            PrivacyProviderRow(
                                provider: .anthropic,
                                name: "Anthropic (Claude)",
                                description: "AI safety focused with constitutional AI principles"
                            )
                            
                            PrivacyProviderRow(
                                provider: .gemini,
                                name: "Google (Gemini)",
                                description: "Advanced multimodal AI with enterprise-grade security"
                            )
                            
                            PrivacyProviderRow(
                                provider: .mistral,
                                name: "Mistral AI",
                                description: "European AI leader delivering fast, efficient models with strong privacy focus"
                            )
                        }
                    }
                    .padding(.top, 8)
                    
                    // Key Points Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Key Privacy Points")
                            .font(.poppins.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            PrivacyKeyPoint(
                                icon: "checkmark.shield.fill",
                                color: .green,
                                title: "Secure Transmission",
                                description: "All data sent via encrypted HTTPS connections"
                            )
                            
                            PrivacyKeyPoint(
                                icon: "hand.raised.fill",
                                color: .orange,
                                title: "No Model Training",
                                description: "Your transcripts are never used to train AI models"
                            )
                            
                            PrivacyKeyPoint(
                                icon: "clock.fill",
                                color: .blue,
                                title: "Temporary Storage",
                                description: "Data stored max 30 days for safety & abuse detection"
                            )
                            
                            PrivacyKeyPoint(
                                icon: "person.fill.checkmark",
                                color: .purple,
                                title: "Your Choice",
                                description: "Select your preferred provider or use app default"
                            )
                        }
                    }
                    .padding(.top, 8)
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.poppins.headline)
                    .foregroundColor(.blue)
                }
            }
        }
    }
}

struct FormattedPrivacyText: View {
    var body: some View {
        let lines = PrivacyStrings.bodyText.components(separatedBy: "\n\n")
        
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                Text(parseFormattedText(line))
                    .font(.poppins.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private func parseFormattedText(_ text: String) -> AttributedString {
        // Use Markdown parsing to support **bold** and other inline styles.
        if let parsed = try? AttributedString(markdown: text) {
            return parsed
        }
        // Fallback to plain text if Markdown parsing fails.
        return AttributedString(text)
    }
}

struct PrivacyProviderRow: View {
    let provider: AIProviderType
    let name: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            provider.iconView(size: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.poppins.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.poppins.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}

struct PrivacyKeyPoint: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.poppins.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.poppins.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    PrivacyInfoView()
}
