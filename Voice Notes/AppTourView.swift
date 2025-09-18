import SwiftUI

// MARK: - Tour Slide Data
struct TourSlide: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let systemImage: String
    let gradientColors: [Color]
    let accentColor: Color
}

// MARK: - App Tour View
struct AppTourView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentSlide = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isAnimating = false
    
    let onComplete: (() -> Void)?
    
    init(onComplete: (() -> Void)? = nil) {
        self.onComplete = onComplete
    }
    
    private let slides: [TourSlide] = [
        TourSlide(
            title: "Voice Recording Made Simple",
            description: "Just tap the microphone to start recording. Your voice is automatically transcribed and summarized using advanced AI with customizable detail levels.",
            systemImage: "mic.circle.fill",
            gradientColors: [.blue.opacity(0.8), .cyan.opacity(0.6)],
            accentColor: .blue
        ),
        TourSlide(
            title: "AI Summaries Your Way",
            description: "Choose from Brief, Standard, or Detailed summaries. Perfect for quick overviews or comprehensive analysis. Customize for medical visits, meetings, or personal notes.",
            systemImage: "brain.head.profile.fill",
            gradientColors: [.purple.opacity(0.8), .indigo.opacity(0.6)],
            accentColor: .purple
        ),
        TourSlide(
            title: "Smart Lists & Organization",
            description: "Create to-do lists, shopping lists, ideas, and meeting notes. Items are automatically organized and color-coded.",
            systemImage: "list.bullet.rectangle.portrait.fill",
            gradientColors: [.green.opacity(0.8), .mint.opacity(0.6)],
            accentColor: .green
        ),
        TourSlide(
            title: "Voice-to-List Magic",
            description: "Add items to your lists using voice input. Simply tap the microphone in any list and speak your items naturally.",
            systemImage: "waveform.badge.plus",
            gradientColors: [.orange.opacity(0.8), .yellow.opacity(0.6)],
            accentColor: .orange
        ),
        TourSlide(
            title: "Powerful Search & Settings",
            description: "Find recordings by content, date, or keywords. Customize summary detail levels, default modes, and explore all features in Settings.",
            systemImage: "magnifyingglass.circle.fill",
            gradientColors: [.orange.opacity(0.8), .pink.opacity(0.6)],
            accentColor: .orange
        ),
        TourSlide(
            title: "Seamless Sharing",
            description: "Share your recordings, transcripts, and lists in multiple formats. Export to other apps or collaborate with your team.",
            systemImage: "square.and.arrow.up.circle.fill",
            gradientColors: [.teal.opacity(0.8), .cyan.opacity(0.6)],
            accentColor: .teal
        )
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: slides[currentSlide].gradientColors + [Color.black.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: currentSlide)
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Main content
                    TabView(selection: $currentSlide) {
                        ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
                            slideView(slide: slide, geometry: geometry)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentSlide)
                    
                    // Bottom controls
                    bottomControls
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                isAnimating = true
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            // Progress indicator
            HStack(spacing: 6) {
                ForEach(0..<slides.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(index <= currentSlide ? .white : .white.opacity(0.3))
                        .frame(width: index == currentSlide ? 24 : 8, height: 6)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentSlide)
                }
            }
            
            Spacer()
            
            // Skip/Close button
            Button(action: completeTour) {
                Text(currentSlide == slides.count - 1 ? "Done" : "Skip")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background {
                        Capsule()
                            .fill(.white.opacity(0.2))
                            .overlay {
                                Capsule()
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            }
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
    
    private func slideView(slide: TourSlide, geometry: GeometryProxy) -> some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon with animated background
            ZStack {
                // Animated background circles
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 180, height: 180)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
                
                Circle()
                    .fill(.white.opacity(0.05))
                    .frame(width: 220, height: 220)
                    .scaleEffect(isAnimating ? 1.1 : 0.9)
                    .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(0.5), value: isAnimating)
                
                // Main icon
                Image(systemName: slide.systemImage)
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(.white)
                    .frame(width: 120, height: 120)
                    .background {
                        Circle()
                            .fill(.white.opacity(0.15))
                            .overlay {
                                Circle()
                                    .stroke(.white.opacity(0.3), lineWidth: 2)
                            }
                    }
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3), value: isAnimating)
            }
            
            // Text content
            VStack(spacing: 16) {
                Text(slide.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 30)
                    .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.5), value: isAnimating)
                
                Text(slide.description)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 20)
                    .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.7), value: isAnimating)
            }
            
            Spacer()
        }
    }
    
    private var bottomControls: some View {
        HStack {
            // Previous button
            Button(action: previousSlide) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Previous")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(currentSlide > 0 ? .white : .white.opacity(0.3))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .disabled(currentSlide == 0)
            .buttonStyle(.plain)
            
            Spacer()
            
            // Next/Get Started button
            Button(action: nextSlide) {
                HStack(spacing: 8) {
                    Text(currentSlide == slides.count - 1 ? "Get Started" : "Next")
                        .font(.system(size: 16, weight: .semibold))
                    
                    if currentSlide < slides.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                    } else {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background {
                    Capsule()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(isAnimating ? 1 : 0.8)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.9), value: isAnimating)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
    
    private func previousSlide() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            if currentSlide > 0 {
                currentSlide -= 1
            }
        }
        
        // Light haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func nextSlide() {
        if currentSlide < slides.count - 1 {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                currentSlide += 1
            }
        } else {
            completeTour()
        }
        
        // Light haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func completeTour() {
        onComplete?()
        dismiss()
        
        // Success haptic feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
}

// MARK: - Preview
#Preview {
    AppTourView()
}