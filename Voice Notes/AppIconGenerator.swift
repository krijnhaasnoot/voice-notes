import SwiftUI

/// Use this view to generate your app icon
/// 1. Run the app in simulator
/// 2. Navigate to this view
/// 3. Take a screenshot of the icon area
/// 4. Crop to 1024x1024 and save as "AppIcon.png"
struct AppIconGenerator: View {
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.blue, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                // Icon preview (1024x1024 equivalent size)
                ZStack {
                    // Outer subtle glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 180
                            )
                        )
                        .frame(width: 360, height: 360)
                        .blur(radius: 20)

                    // Main icon container (this is what you'll screenshot)
                    RoundedRectangle(cornerRadius: 72)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 320, height: 320)
                        .overlay {
                            // Waveform icon
                            Image(systemName: "waveform")
                                .font(.system(size: 140, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: .black.opacity(0.3), radius: 30, y: 15)
                }

                VStack(spacing: 12) {
                    Text("Voice Notes App Icon")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Screenshot the rounded square above")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))

                    Text("1024x1024 pixels")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
    }
}

// Alternative versions with different styles
struct AppIconGeneratorVariant1: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 72)
            .fill(.white)
            .frame(width: 320, height: 320)
            .overlay {
                Image(systemName: "waveform")
                    .font(.system(size: 140, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
    }
}

struct AppIconGeneratorVariant2: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 72)
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.2, green: 0.4, blue: 1.0),
                             Color(red: 0.6, green: 0.2, blue: 1.0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 320, height: 320)
            .overlay {
                ZStack {
                    // Multiple waveforms for depth
                    Image(systemName: "waveform")
                        .font(.system(size: 140, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                        .offset(x: -10, y: -10)

                    Image(systemName: "waveform")
                        .font(.system(size: 140, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
    }
}

#Preview("Main Icon") {
    AppIconGenerator()
}

#Preview("White Background") {
    AppIconGeneratorVariant1()
        .padding()
        .background(Color.gray.opacity(0.2))
}

#Preview("Depth Effect") {
    AppIconGeneratorVariant2()
        .padding()
        .background(Color.black)
}
