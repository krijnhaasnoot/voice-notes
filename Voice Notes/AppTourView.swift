import SwiftUI

// MARK: - App Tour View
struct AppTourView: View {
    let onComplete: () -> Void
    @State private var currentPage = 0
    private let totalPages = 4
    
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
                    
                    // Page 4: Search
                    TourPage(
                        systemImage: "magnifyingglass",
                        title: "Find Anything Fast",
                        description: "Search through all your recordings and documents instantly. Never lose an important thought again.",
                        gradient: LinearGradient(colors: [.purple.opacity(0.8), .purple], startPoint: .top, endPoint: .bottom)
                    )
                    .tag(3)
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
