import SwiftUI


struct ProviderAuthorizationView: View {
    // Input from parent
    let provider: AIProviderType
    let onComplete: () -> Void

    // Internal, stable snapshot of provider to avoid SwiftUI reuse/caching glitches
    @State private var effectiveProvider: AIProviderType

    @ObservedObject private var aiSettings = AISettingsStore.shared
    @State private var isConnecting = false
    @State private var showingManualEntry = false
    @State private var connectionStatus: ConnectionStatus = .notConnected
    @State private var isLoading = true
    
    init(provider: AIProviderType, onComplete: @escaping () -> Void) {
        self.provider = provider
        self.onComplete = onComplete
        _effectiveProvider = State(initialValue: provider)
        print("🏗️ ProviderAuthorizationView init with provider: \(provider.displayName)")
    }
    
    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else {
                VStack(spacing: 24) {
                    providerHeaderView
                    connectionStatusView
                    Spacer()
                    connectButtonsView
                    Spacer()
                    manualEntryOption
                }
                .padding(.horizontal, 24)
            }
        }
        .id("provider-\(effectiveProvider.rawValue)") // Force complete view recreation when provider changes
        .onAppear {
            print("🎭 ProviderAuthorizationView body rendered with provider: \(effectiveProvider.displayName)")
        }
        .navigationTitle("Connect to \(effectiveProvider.displayName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onComplete)
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            NavigationStack {
                ManualAPIKeyView(provider: effectiveProvider, onComplete: onComplete)
            }
        }
        .onAppear {
            // Ensure clean state when view appears
            isLoading = true
            isConnecting = false
            showingManualEntry = false
            connectionStatus = .notConnected
        }
        .task(id: effectiveProvider) {
            // Immediately show loading and reset ALL state to prevent showing cached data from other providers
            await MainActor.run {
                print("🔄 Task triggered for provider: \(effectiveProvider.displayName)")
                isLoading = true
                isConnecting = false
                showingManualEntry = false
                connectionStatus = .notConnected
            }
            initializeForProvider()
        }
        .onChange(of: provider) { _, newProvider in
            // Force a clean state anytime the provider changes to avoid view/state contamination
            effectiveProvider = newProvider
            isLoading = true
            isConnecting = false
            showingManualEntry = false
            connectionStatus = .notConnected
            // Re-run initialization for the new provider
            initializeForProvider()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            // Match the exact spacing and structure of providerHeaderView
            VStack(spacing: 16) {
                effectiveProvider.iconView(size: 64)
                    .padding(.top, 20)
                    .overlay(
                        // Subtle shimmer effect during loading
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [Color.clear, Color.white.opacity(0.3), Color.clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .opacity(0.6)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: true)
                    )
                    .onAppear {
                        print("🔄 LoadingView showing provider: \(effectiveProvider.displayName)")
                    }

                Text(effectiveProvider.displayName)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Loading connection details...")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Elegant loading indicator
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                    .tint(effectiveProvider.accentColor)

                Text("Preparing secure connection...")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Placeholder for buttons area to maintain layout consistency
            VStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 50)
                    .overlay(
                        ProgressView()
                            .controlSize(.small)
                            .tint(.gray)
                    )

                Text("Setting up provider options...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .opacity(0.6)

            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Provider Header
    
    private var providerHeaderView: some View {
        VStack(spacing: 16) {
            effectiveProvider.iconView(size: 64)
                .padding(.top, 20)

            Text(effectiveProvider.displayName)
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(effectiveProvider.shortDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Connection Status
    
    private var connectionStatusView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: connectionStatus.iconName)
                    .foregroundColor(connectionStatus.color)

                Text(connectionStatus.message)
                    .font(.headline)
                    .foregroundColor(connectionStatus.color)
            }

            if connectionStatus == .connected {
                VStack(spacing: 4) {
                    Text("You're all set! Voice Notes can now use \(effectiveProvider.displayName) for summaries.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    if aiSettings.selectedProvider == effectiveProvider {
                        Text("✅ This provider is currently active")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    } else {
                        Button("Switch to \(effectiveProvider.displayName)") {
                            aiSettings.selectedProvider = effectiveProvider
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.vertical, 2)
                    }
                }
            } else if connectionStatus == .connecting {
                VStack(spacing: 8) {
                    Text("After creating your API key, return here and use 'Enter API Key Manually' below.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Text("The webpage should now be open in Safari where you can:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. Sign in to your account")
                        Text("2. Create a new API key")
                        Text("3. Copy the key")
                        Text("4. Return here and paste it")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(connectionStatus.backgroundColor)
        .cornerRadius(12)
    }
    
    // MARK: - Connect Buttons
    
    private var connectButtonsView: some View {
        VStack(spacing: 16) {
            if connectionStatus != .connected {
                Button(action: connectWithProvider) {
                    HStack {
                        if isConnecting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "link")
                        }

                        Text(isConnecting ? "Opening..." : "Get API Key from \(effectiveProvider.displayName)")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(effectiveProvider.accentColor)
                    .cornerRadius(12)
                }
                .disabled(isConnecting)

                Text(effectiveProvider.authInstructions)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Button("Disconnect") {
                    disconnectProvider()
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Manual Entry Option
    
    private var manualEntryOption: some View {
        VStack(spacing: 12) {
            if connectionStatus == .connecting {
                // Prominently show manual entry after they've opened the website
                Button("Paste API Key Here") {
                    showingManualEntry = true
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .fontWeight(.semibold)
            } else {
                // Show as secondary option when not connected
                VStack(spacing: 8) {
                    Text("Advanced Users")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    Button("Enter API Key Manually") {
                        showingManualEntry = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func connectWithProvider() {
        isConnecting = true

        print("🔗 Connecting with provider: \(effectiveProvider) - \(effectiveProvider.displayName)")
        
        // Get provider-specific URL and ensure it's correct
        let setupURL = getProviderSetupURL()
        print("🔗 Setup URL for \(effectiveProvider): \(setupURL?.absoluteString ?? "nil")")

        // Open the provider's API key setup page in Safari
        if let url = setupURL {
            print("🔗 Opening setup URL: \(url.absoluteString)")
            UIApplication.shared.open(url)

            // Show instructions to user
            Task { @MainActor in
                connectionStatus = .connecting
                isConnecting = false
                print("🔗 Updated connection status to connecting for \(effectiveProvider)")
            }
        } else {
            print("❌ No setup URL available for provider: \(effectiveProvider.displayName)")
            Task { @MainActor in
                connectionStatus = .error("Unable to open setup page")
                isConnecting = false
            }
        }
    }

    private func getProviderSetupURL() -> URL? {
        switch effectiveProvider {
        case .appDefault: return nil
        case .openai:     return URL(string: "https://platform.openai.com/api-keys")
        case .anthropic:  return URL(string: "https://console.anthropic.com/settings/keys")
        case .gemini:     return URL(string: "https://aistudio.google.com/app/apikey")
        default:
            // Handle any other providers (like mistral) dynamically
            if effectiveProvider.rawValue == "mistral" {
                return URL(string: "https://console.mistral.ai/api-keys/")
            }
            return nil
        }
    }

    private func disconnectProvider() {
        aiSettings.removeApiKey(for: effectiveProvider)
        connectionStatus = .notConnected
    }

    private func initializeForProvider() {
        print("🚀 Initializing for provider: \(effectiveProvider.displayName)")
        // Quick initialization with minimal delay for smooth UX
        Task {
            // Brief pause to ensure UI has updated with loading state
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds (reduced from 0.5s)

            await MainActor.run {
                print("✅ Checking API key for provider: \(effectiveProvider.displayName)")
                // Check connection status for the current provider
                let hasKey = aiSettings.hasApiKey(for: effectiveProvider)
                let validationState = aiSettings.providerValidationStates[effectiveProvider]
                print("🔑 Provider \(effectiveProvider.displayName): hasKey=\(hasKey), validationState=\(String(describing: validationState))")
                
                if hasKey {
                    print("🔑 Found API key for \(effectiveProvider.displayName)")
                    connectionStatus = .connected
                } else {
                    print("❌ No API key found for \(effectiveProvider.displayName)")
                    connectionStatus = .notConnected
                }

                // Hide loading with smooth animation
                withAnimation(.easeInOut(duration: 0.2)) {
                    isLoading = false
                }
                print("✨ Finished initializing \(effectiveProvider.displayName) - Status: \(connectionStatus)")
            }
        }
    }

    private func simulateOAuthFlow() async throws {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 2_000_000_000)

        // For demo purposes, create a mock API key
        let mockApiKey = generateMockApiKey(for: effectiveProvider)
        await aiSettings.storeApiKey(mockApiKey, for: effectiveProvider)
    }
    
    private func generateMockApiKey(for provider: AIProviderType) -> String {
        switch provider {
        case .appDefault:
            return ""
        case .openai:
            return "sk-mock-" + String((0..<48).map { _ in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
        case .anthropic:
            return "sk-ant-mock-" + String((0..<90).map { _ in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_".randomElement()! })
        case .gemini:
            return String((0..<39).map { _ in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_".randomElement()! })
        default:
            // Handle any other providers (like mistral) dynamically
            if provider.rawValue == "mistral" {
                return String((0..<32).map { _ in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
            }
            return ""
        }
    }
}

// MARK: - Connection Status

enum ConnectionStatus: Equatable {
    case notConnected
    case connecting
    case connected
    case error(String)
    
    static func == (lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.notConnected, .notConnected),
             (.connecting, .connecting),
             (.connected, .connected):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
    
    var message: String {
        switch self {
        case .notConnected:
            return "Not Connected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .error(let message):
            return "Connection Error"
        }
    }
    
    var color: Color {
        switch self {
        case .notConnected:
            return .secondary
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .error:
            return .red
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .notConnected:
            return Color.secondary.opacity(0.1)
        case .connecting:
            return Color.orange.opacity(0.1)
        case .connected:
            return Color.green.opacity(0.1)
        case .error:
            return Color.red.opacity(0.1)
        }
    }
    
    var iconName: String {
        switch self {
        case .notConnected:
            return "link.slash"
        case .connecting:
            return "clock"
        case .connected:
            return "checkmark.circle"
        case .error:
            return "exclamationmark.triangle"
        }
    }
}

// MARK: - Manual API Key Entry (fallback)

struct ManualAPIKeyView: View {
    let provider: AIProviderType
    let onComplete: () -> Void

    @State private var apiKey = ""
    @State private var isValidating = false
    @State private var validationMessage = ""
    @State private var showValidationResult = false
    @ObservedObject private var aiSettings = AISettingsStore.shared

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 16) {
                provider.iconView(size: 48)

                Text("Paste Your \(provider.displayName) API Key")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(provider.keyFormatHint)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            // API Key Input
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(.headline)
                        .foregroundColor(.primary)

                    SecureField("Paste your API key here", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                        .font(.system(.body, design: .monospaced))

                    if showValidationResult {
                        HStack {
                            Image(systemName: validationMessage.contains("✅") ? "checkmark.circle" : "xmark.circle")
                                .foregroundColor(validationMessage.contains("✅") ? .green : .red)
                            Text(validationMessage)
                                .font(.caption)
                                .foregroundColor(validationMessage.contains("✅") ? .green : .red)
                        }
                    }
                }

                Button(action: validateAndSave) {
                    HStack {
                        if isValidating {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text(isValidating ? "Validating..." : "Validate & Save")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(apiKey.isEmpty ? Color.gray : provider.accentColor)
                    .cornerRadius(12)
                }
                .disabled(apiKey.isEmpty || isValidating)
            }
            .padding(.horizontal)

            Spacer()

            // Help Text
            VStack(spacing: 8) {
                Text("Need help finding your API key?")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Open \(provider.developerPortalURL)") {
                    let urlString = "https://\(provider.developerPortalURL)"
                    print("🔗 Opening URL for \(provider.displayName): \(urlString)")
                    if let url = URL(string: urlString) {
                        UIApplication.shared.open(url)
                    } else {
                        print("❌ Failed to create URL from: \(urlString)")
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
        }
        .padding()
        .navigationTitle("")
        .navigationBarHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onComplete)
            }
        }
    }
    
    private func validateAndSave() {
        Task {
            isValidating = true
            showValidationResult = false
            
            do {
                let isValid = try await ProviderRegistry.shared.validateProvider(provider, apiKey: apiKey)
                
                if isValid {
                    await aiSettings.storeApiKey(apiKey, for: provider)
                    
                    // Automatically select this provider since they just configured it
                    await MainActor.run {
                        aiSettings.selectedProvider = provider
                    }
                    
                    validationMessage = "✅ API key is valid, saved, and now active"
                    
                    // Auto-close after successful validation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        onComplete()
                    }
                } else {
                    validationMessage = "❌ API key validation failed"
                }
                
                showValidationResult = true
                
            } catch {
                validationMessage = "❌ Error: \(error.localizedDescription)"
                showValidationResult = true
            }
            
            isValidating = false
        }
    }
}

// MARK: - Provider Extensions

extension AIProviderType {
    var iconName: String {
        switch self {
        case .appDefault:
            return "brain.head.profile"
        case .openai:
            return "openai-icon"
        case .anthropic:
            return "Claude_AI_symbol.svg"
        case .gemini:
            return "gemini-color"
        default:
            // Handle any other providers (like mistral) dynamically
            if self.rawValue == "mistral" {
                return "Mistral"
            }
            return "brain.head.profile"
        }
    }

    var accentColor: Color {
        switch self {
        case .appDefault:
            return .blue
        case .openai:
            return Color(red: 0.07, green: 0.73, blue: 0.62) // OpenAI brand teal
        case .anthropic:
            return Color(red: 0.90, green: 0.49, blue: 0.13) // Claude/Anthropic orange
        case .gemini:
            return Color(red: 0.26, green: 0.52, blue: 0.96) // Google Blue
        default:
            // Handle any other providers (like mistral) dynamically
            if self.rawValue == "mistral" {
                return Color(red: 0.11, green: 0.60, blue: 0.80) // Mistral brand teal
            }
            return .blue
        }
    }

    var fallbackSystemIcon: String {
        switch self {
        case .appDefault:
            return "brain.head.profile"
        case .openai:
            return "cpu"
        case .anthropic:
            return "brain"
        case .gemini:
            return "star"
        default:
            // Handle any other providers (like mistral) dynamically
            if self.rawValue == "mistral" {
                return "wind"
            }
            return "brain.head.profile"
        }
    }

    @ViewBuilder
    func iconView(size: CGFloat = 64) -> some View {
        // Consistent container with fixed dimensions to prevent layout shifts
        ZStack {
            // Invisible background to maintain consistent bounds
            RoundedRectangle(cornerRadius: size * 0.1)
                .fill(Color.clear)
                .frame(width: size, height: size)

            Group {
                if self == .appDefault {
                    Image(systemName: self.iconName)
                        .font(.system(size: size * 0.6, weight: .medium))
                        .frame(width: size * 0.8, height: size * 0.8)
                } else if UIImage(named: self.iconName) != nil {
                    Image(self.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size * 0.75, height: size * 0.75)
                        .clipped()
                        .onAppear {
                            print("🎨 Loaded brand image for: \(self.displayName) - Icon: \(self.iconName)")
                        }
                } else {
                    // Fallback to a safe SF Symbol if the brand asset cannot be loaded (e.g., bad filename)
                    Image(systemName: self.fallbackSystemIcon)
                        .font(.system(size: size * 0.6, weight: .medium))
                        .frame(width: size * 0.8, height: size * 0.8)
                        .onAppear {
                            print("⚠️ Brand image not found for \(self.displayName) (\"\(self.iconName)\"). Using fallback symbol: \(self.fallbackSystemIcon)")
                        }
                }
            }
        }
        .foregroundColor(self.accentColor)
        .id("icon-\(self.rawValue)") // Simple ID based on provider
    }

    var shortDescription: String {
        switch self {
        case .appDefault:
            return "Use the app's default AI service"
        case .openai:
            return "Connect your OpenAI account for GPT-powered summaries"
        case .anthropic:
            return "Connect your Anthropic account for Claude-powered summaries"
        case .gemini:
            return "Connect your Google account for Gemini-powered summaries"
        default:
            // Handle any other providers (like mistral) dynamically
            if self.rawValue == "mistral" {
                return "Connect your Mistral account for fast, affordable summaries"
            }
            return "Connect your account for AI-powered summaries"
        }
    }

    var authInstructions: String {
        switch self {
        case .appDefault:
            return ""
        case .openai:
            return "Opens OpenAI Platform where you can create an API key. You'll need to add credits to your account."
        case .anthropic:
            return "Opens Anthropic Console where you can create an API key. New accounts get $5 free credits."
        case .gemini:
            return "Opens Google AI Studio where you can create a free API key with generous usage limits."
        default:
            // Handle any other providers (like mistral) dynamically
            if self.rawValue == "mistral" {
                return "Opens Mistral Console where you can create an API key. Affordable, fast models."
            }
            return "Opens the provider's console where you can create an API key."
        }
    }

    var developerPortalURL: String {
        switch self {
        case .appDefault:
            return ""
        case .openai:
            return "platform.openai.com"
        case .anthropic:
            return "console.anthropic.com"
        case .gemini:
            return "aistudio.google.com"
        default:
            // Handle any other providers (like mistral) dynamically
            if self.rawValue == "mistral" {
                return "console.mistral.ai"
            }
            return ""
        }
    }

    var keyFormatHint: String {
        switch self {
        case .appDefault:
            return ""
        case .openai:
            return "Should start with 'sk-' and be about 48 characters long"
        case .anthropic:
            return "Should start with 'sk-ant-' and be about 95 characters long"
        case .gemini:
            return "Should be about 39 characters long (starts with letters/numbers)"
        default:
            // Handle any other providers (like mistral) dynamically
            if self.rawValue == "mistral" {
                return "Should start with 'sk-' and be roughly 40–64 characters"
            }
            return "Please check your provider's documentation for the expected format"
        }
    }
}

// MARK: - Preview

#Preview {
    ProviderAuthorizationView(provider: AIProviderType(rawValue: "mistral") ?? .openai) { }
}
