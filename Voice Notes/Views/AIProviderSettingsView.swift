import SwiftUI

struct AIProviderSettingsView: View {
    @StateObject private var aiSettings = AISettingsStore.shared
    @State private var showingApiKeySheet = false
    @State private var selectedProviderForKeyEntry: AIProviderType?
    
    var body: some View {
        Form {
            providerSelectionSection
            providersConfigurationSection
            transparencySection
        }
        .navigationTitle("AI Providers")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showingApiKeySheet) {
            if let provider = selectedProviderForKeyEntry {
                ProviderAuthorizationView(provider: provider) {
                    showingApiKeySheet = false
                    selectedProviderForKeyEntry = nil
                }
            }
        }
        .task {
            await aiSettings.refreshValidationStates()
        }
    }
    
    // MARK: - Provider Selection Section
    
    private var providerSelectionSection: some View {
        Section(header: Text("Selected Provider")) {
            Picker("AI Provider", selection: $aiSettings.selectedProvider) {
                ForEach(AIProviderType.allCases, id: \.self) { provider in
                    HStack {
                        Text(provider.displayName)
                        Spacer()
                        if !aiSettings.canUseProvider(provider) && provider != .appDefault {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                    }
                    .tag(provider)
                }
            }
            .pickerStyle(.menu)
            
            // Show warning if selected provider is not properly configured
            if !aiSettings.canUseProvider(aiSettings.selectedProvider) && aiSettings.selectedProvider != .appDefault {
                Label("Selected provider needs configuration", systemImage: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        }
    }
    
    // MARK: - Providers Configuration Section
    
    private var providersConfigurationSection: some View {
        Section(header: Text("Provider Configuration")) {
            ForEach(AIProviderType.allCases, id: \.self) { provider in
                ProviderConfigurationRow(
                    provider: provider,
                    validationState: aiSettings.providerValidationStates[provider] ?? .notValidated,
                    hasApiKey: aiSettings.hasApiKey(for: provider),
                    onConfigureTapped: {
                        print("🔑 Setting up API key entry for: \(provider.displayName)")
                        selectedProviderForKeyEntry = provider
                        showingApiKeySheet = true
                    },
                    onRemoveTapped: {
                        aiSettings.removeApiKey(for: provider)
                    },
                    onValidateTapped: {
                        Task {
                            await aiSettings.validateProvider(provider)
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Transparency Section
    
    private var transparencySection: some View {
        Section(
            header: Text("Transparency"),
            footer: Text("When you connect your own accounts, summaries are processed directly by your chosen provider. Costs are billed to your provider account. Voice Notes uses secure OAuth authorization and stores credentials safely in your device's Keychain.")
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Direct connection to your provider account", systemImage: "link")
                Label("Summaries processed by chosen provider", systemImage: "cloud.fill")
                Label("Costs billed to your provider account", systemImage: "creditcard.fill")
                Label("Secure OAuth authorization", systemImage: "shield.checkered")
                Label("Credentials stored securely in Keychain", systemImage: "lock.fill")
                Label("No logging of credentials or transcript content", systemImage: "eye.slash.fill")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}

// MARK: - Provider Configuration Row

struct ProviderConfigurationRow: View {
    let provider: AIProviderType
    let validationState: ValidationState
    let hasApiKey: Bool
    let onConfigureTapped: () -> Void
    let onRemoveTapped: () -> Void
    let onValidateTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if provider.requiresApiKey {
                        HStack(spacing: 6) {
                            Image(systemName: validationState.systemImage)
                                .foregroundColor(validationState.statusColor)
                                .font(.caption)
                            
                            Text(validationState.statusText)
                                .font(.caption)
                                .foregroundColor(validationState.statusColor)
                        }
                    } else {
                        Text("No API key required")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if provider.requiresApiKey {
                    HStack(spacing: 8) {
                        if hasApiKey && validationState == .notValidated {
                            Button("Validate", action: onValidateTapped)
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                        
                        Button(hasApiKey ? "Reconnect" : "Connect") {
                            print("🔑 Connect button tapped for provider: \(provider.displayName)")
                            onConfigureTapped()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        if hasApiKey {
                            Button("Remove") {
                                onRemoveTapped()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(.red)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - API Key Entry View

struct APIKeyEntryView: View {
    let provider: AIProviderType
    let onComplete: () -> Void
    
    @ObservedObject private var aiSettings = AISettingsStore.shared
    @State private var apiKey = ""
    @State private var isValidating = false
    @State private var validationMessage = ""
    @State private var showingValidationResult = false
    
    var body: some View {
        Form {
            // Test section to ensure view renders
            Section {
                Text("Setting up API key for \(provider.displayName)")
                    .font(.headline)
            }
            
            Section(
                header: Text("\(provider.displayName) API Key"),
                footer: Text(keyInstructionsText)
            ) {
                SecureField("Enter API key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .textContentType(.password)
                
                if showingValidationResult {
                    HStack {
                        Image(systemName: validationMessage.contains("✅") ? "checkmark.circle" : "xmark.circle")
                            .foregroundColor(validationMessage.contains("✅") ? .green : .red)
                        
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundColor(validationMessage.contains("✅") ? .green : .red)
                    }
                }
            }
            
            Section {
                Button(action: validateAndSaveKey) {
                    HStack {
                        if isValidating {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.8)
                        }
                        
                        Text(isValidating ? "Validating..." : "Validate & Save")
                    }
                }
                .disabled(apiKey.isEmpty || isValidating)
            }
        }
        .navigationTitle("API Key Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onComplete)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await aiSettings.storeApiKey(apiKey, for: provider)
                        onComplete()
                    }
                }
                .disabled(apiKey.isEmpty)
            }
        }
        .onAppear {
            print("🔑 APIKeyEntryView appeared for provider: \(provider.displayName)")
        }
    }
    
    private var keyInstructionsText: String {
        switch provider {
        case .appDefault:
            return ""
        case .openai:
            return "Get your API key from platform.openai.com. It should start with 'sk-'."
        case .anthropic:
            return "Get your API key from console.anthropic.com. It should start with 'sk-ant-'."
        case .gemini:
            return "Get your API key from makersuite.google.com. It's a 39-character string."
        }
    }
    
    private func validateAndSaveKey() {
        Task {
            isValidating = true
            showingValidationResult = false
            
            do {
                let isValid = try await ProviderRegistry.shared.validateProvider(provider, apiKey: apiKey)
                
                if isValid {
                    await aiSettings.storeApiKey(apiKey, for: provider)
                    validationMessage = "✅ API key is valid and saved"
                    
                    // Auto-close after successful validation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        onComplete()
                    }
                } else {
                    validationMessage = "❌ API key validation failed"
                }
                
                showingValidationResult = true
                
            } catch {
                validationMessage = "❌ Error: \(error.localizedDescription)"
                showingValidationResult = true
            }
            
            isValidating = false
        }
    }
}

// MARK: - Previews

#Preview {
    AIProviderSettingsView()
}
