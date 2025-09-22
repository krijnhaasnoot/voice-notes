import SwiftUI

struct RecordingProviderPickerView: View {
    @Binding var selectedProvider: AIProviderType?
    @StateObject private var aiSettings = AISettingsStore.shared
    let onSelectionChanged: (AIProviderType?) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Provider for Summary")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Choose which AI provider to use for this recording's summary. Leave as 'Use Global Setting' to use your default provider.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Picker("AI Provider", selection: bindingProvider) {
                Text("Use Global Setting (\(aiSettings.selectedProvider.displayName))")
                    .tag(nil as AIProviderType?)
                
                Divider()
                
                ForEach(AIProviderType.allCases, id: \.self) { provider in
                    HStack {
                        Text(provider.displayName)
                        
                        if !aiSettings.canUseProvider(provider) && provider != .appDefault {
                            Spacer()
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                    }
                    .tag(provider as AIProviderType?)
                }
            }
            .pickerStyle(.menu)
            
            // Show status for selected provider
            if let provider = selectedProvider {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: aiSettings.canUseProvider(provider) ? "checkmark.circle" : "exclamationmark.triangle")
                            .foregroundColor(aiSettings.canUseProvider(provider) ? .green : .orange)
                            .font(.caption)
                        
                        Text(aiSettings.canUseProvider(provider) ? 
                             "Ready to use \(provider.displayName)" :
                             "\(provider.displayName) needs configuration")
                            .font(.caption)
                            .foregroundColor(aiSettings.canUseProvider(provider) ? .green : .orange)
                    }
                    
                    if !aiSettings.canUseProvider(provider) && provider != .appDefault {
                        NavigationLink("Configure \(provider.displayName)", destination: AIProviderSettingsView())
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var bindingProvider: Binding<AIProviderType?> {
        Binding(
            get: { selectedProvider },
            set: { newProvider in
                selectedProvider = newProvider
                onSelectionChanged(newProvider)
            }
        )
    }
}

// MARK: - Preview

#Preview {
    RecordingProviderPickerView(
        selectedProvider: .constant(.openai),
        onSelectionChanged: { _ in }
    )
}