import SwiftUI

struct AnimatedSplashView: View {
    @State private var scale: CGFloat = 0.7
    @State private var opacity: Double = 0.0
    @State private var ready = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            // Use app icon or create a simple logo view
            VStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 100, weight: .light))
                    .foregroundColor(.blue)
                Text("Voice Notes")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    scale = 1.0
                    opacity = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        ready = true
                    }
                }
            }
        }
        .overlay(Group {
            if ready {
                RootView()
                    .transition(.opacity)
            }
        })
    }
}