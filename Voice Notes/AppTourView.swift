import SwiftUI
import AVFoundation

// MARK: - App Tour View
struct AppTourView: View {
    let onComplete: () -> Void
    @State private var currentPage = 0
    private let totalPages = 6
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        onComplete()
                    }
                    .font(.poppins.medium(size: 16))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                
                // Tour content
                TabView(selection: $currentPage) {
                    // Page 1: Welcome
                    TourPage(
                        systemImage: "mic.fill",
                        title: "Welcome to Voice Notes",
                        description: "Capture your thoughts instantly with voice recording and automatic transcription.",
                        gradient: LinearGradient(colors: [.blue.opacity(0.8), .blue], startPoint: .top, endPoint: .bottom)
                    )
                    .tag(0)
                    
                    // Page 2: Recording
                    TourPage(
                        systemImage: "waveform",
                        title: "Smart Transcription",
                        description: "Your recordings are automatically transcribed and summarized using advanced AI.",
                        gradient: LinearGradient(colors: [.green.opacity(0.8), .green], startPoint: .top, endPoint: .bottom)
                    )
                    .tag(1)
                    
                    // Page 3: Organization
                    TourPage(
                        systemImage: "doc.text.fill",
                        title: "Organize Your Lists",
                        description: "Create different types of documents: todo lists, shopping lists, meeting notes, and ideas.",
                        gradient: LinearGradient(colors: [.orange.opacity(0.8), .orange], startPoint: .top, endPoint: .bottom)
                    )
                    .tag(2)
                    
                    // Page 4: Privacy & AI
                    PrivacyTourPage()
                    .tag(3)
                    
                    // Page 5: Permissions
                    PermissionsTourPage(onComplete: onComplete)
                    .tag(4)
                    
                    // Page 6: Search
                    TourPage(
                        systemImage: "magnifyingglass",
                        title: "Find Anything Fast",
                        description: "Search through all your recordings and documents instantly. Never lose an important thought again.",
                        gradient: LinearGradient(colors: [.purple.opacity(0.8), .purple], startPoint: .top, endPoint: .bottom)
                    )
                    .tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)
                
                // Page indicator and navigation
                VStack(spacing: 24) {
                    // Custom page indicator
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? .blue : .blue.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(index == currentPage ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                        }
                    }
                    
                    // Navigation buttons
                    HStack(spacing: 20) {
                        if currentPage > 0 {
                            Button("Previous") {
                                withAnimation {
                                    currentPage -= 1
                                }
                            }
                            .font(.poppins.medium(size: 16))
                            .foregroundColor(.blue)
                            .frame(width: 100)
                        } else {
                            Spacer()
                                .frame(width: 100)
                        }
                        
                        Button(currentPage == totalPages - 1 ? "Get Started" : "Next") {
                            if currentPage == totalPages - 1 {
                                onComplete()
                            } else {
                                withAnimation {
                                    currentPage += 1
                                }
                            }
                        }
                        .font(.poppins.semiBold(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 120, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(LinearGradient(colors: [.blue.opacity(0.8), .blue], startPoint: .top, endPoint: .bottom))
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                        .if(isLiquidGlassAvailable) { view in
                            view.glassEffect(.regular)
                        }
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .interactiveDismissDisabled()
    }
}

// MARK: - Permissions Tour Page
private struct PermissionsTourPage: View {
    let onComplete: () -> Void
    @State private var permissionStatus: AVAudioSession.RecordPermission = .undetermined
    @State private var isRequestingPermission = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.pink.opacity(0.8), .pink], startPoint: .top, endPoint: .bottom))
                    .frame(width: 120, height: 120)
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                
                Image(systemName: permissionStatus == .granted ? "checkmark.circle.fill" : "mic.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            }
            
            // Text content
            VStack(spacing: 16) {
                Text(permissionStatus == .granted ? "All Set!" : "Microphone Access")
                    .font(.poppins.bold(size: 28))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                
                Text(permissionStatus == .granted ? 
                     "Great! You're ready to start recording your voice notes." : 
                     "To record your voice notes, Voice Notes needs access to your microphone. Your recordings stay private and secure on your device.")
                    .font(.poppins.regular(size: 18))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            
            // Permission features
            if permissionStatus != .granted {
                VStack(spacing: 12) {
                    PermissionPoint(
                        icon: "lock.shield.fill",
                        text: "Your recordings never leave your device",
                        color: .green
                    )
                    
                    PermissionPoint(
                        icon: "gear",
                        text: "You can change this anytime in Settings",
                        color: .blue
                    )
                    
                    PermissionPoint(
                        icon: "hand.raised.fill",
                        text: "No background recording or listening",
                        color: .orange
                    )
                }
                .padding(.horizontal, 40)
            }
            
            // Permission button
            if permissionStatus != .granted && !isRequestingPermission {
                Button(action: requestPermission) {
                    HStack(spacing: 12) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Allow Microphone Access")
                            .font(.poppins.semiBold(size: 16))
                    }
                    .foregroundColor(.white)
                    .frame(height: 48)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(LinearGradient(colors: [.pink.opacity(0.8), .pink], startPoint: .top, endPoint: .bottom))
                    )
                    .shadow(color: .pink.opacity(0.3), radius: 8, y: 4)
                }
                .padding(.horizontal, 40)
            }
            
            if isRequestingPermission {
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.pink)
                    
                    Text("Requesting permission...")
                        .font(.poppins.medium(size: 16))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            checkCurrentPermissionStatus()
        }
    }
    
    private func checkCurrentPermissionStatus() {
        permissionStatus = AVAudioSession.sharedInstance().recordPermission
    }
    
    private func requestPermission() {
        isRequestingPermission = true
        
        Task {
            let granted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { result in
                    continuation.resume(returning: result)
                }
            }
            
            await MainActor.run {
                self.permissionStatus = granted ? .granted : .denied
                self.isRequestingPermission = false
                
                // If granted, automatically continue to next page after a brief delay
                if granted {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        onComplete()
                    }
                }
            }
        }
    }
}

private struct PermissionPoint: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            Text(text)
                .font(.poppins.medium(size: 14))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Privacy Tour Page
private struct PrivacyTourPage: View {
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.teal.opacity(0.8), .teal], startPoint: .top, endPoint: .bottom))
                    .frame(width: 120, height: 120)
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            }
            
            // Text content
            VStack(spacing: 16) {
                Text(PrivacyStrings.tourTitle)
                    .font(.poppins.bold(size: 28))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                
                Text(PrivacyStrings.tourDescription)
                    .font(.poppins.regular(size: 18))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            
            // Key privacy points
            VStack(spacing: 12) {
                PrivacyTourPoint(
                    icon: "checkmark.shield.fill",
                    text: "Secure transmission to your chosen AI provider",
                    color: .green
                )
                
                PrivacyTourPoint(
                    icon: "hand.raised.fill",
                    text: "Your data is never used for AI training",
                    color: .orange
                )
                
                PrivacyTourPoint(
                    icon: "person.fill.checkmark",
                    text: "You control which provider to use",
                    color: .blue
                )
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PrivacyTourPoint: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            Text(text)
                .font(.poppins.medium(size: 14))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Tour Page Component
private struct TourPage: View {
    let systemImage: String
    let title: String
    let description: String
    let gradient: LinearGradient
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(gradient)
                    .frame(width: 120, height: 120)
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                
                Image(systemName: systemImage)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            }
            
            // Text content
            VStack(spacing: 16) {
                Text(title)
                    .font(.poppins.bold(size: 28))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.poppins.regular(size: 18))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}




// MARK: - Preview
#Preview {
    AppTourView(onComplete: {
        print("Tour completed!")
    })
}
