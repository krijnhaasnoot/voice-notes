#if os(watchOS)
import SwiftUI
import WatchKit

struct WatchHomeView: View {
    @ObservedObject private var viewModel = WatchRecorderViewModel.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Connection status indicator at top
            HStack {
                Circle()
                    .fill(viewModel.isReachable && viewModel.isConnectivityActivated ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(connectionStatusText)
                    .font(.system(.caption2))
                    .foregroundColor(.secondary)
                Spacer()
                
                // Retry button when not connected
                if !viewModel.isReachable || !viewModel.isConnectivityActivated {
                    Button("Retry") {
                        viewModel.retryConnection()
                    }
                    .font(.system(.caption2))
                    .foregroundColor(.blue)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            
            Spacer()
            
            // Large recording section
            VStack(spacing: 16) {
                // Status text
                VStack(spacing: 6) {
                    if !viewModel.statusText.isEmpty {
                        Text(viewModel.statusText)
                            .font(.system(.body, weight: .medium))
                            .foregroundColor(statusColor)
                            .multilineTextAlignment(.center)
                    } else {
                        Text(recordingStatusText)
                            .font(.system(.body, weight: .medium))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                    }
                    
                    if viewModel.isRecording {
                        Text(DurationFormatter.format(viewModel.duration))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Large record button with pause if recording
                HStack(spacing: 12) {
                    // Pause button (only visible when recording)
                    if viewModel.isRecording {
                        Button(action: secondaryButtonAction) {
                            ZStack {
                                Circle()
                                    .fill(.regularMaterial)
                                    .frame(width: 45, height: 45)
                                    .overlay {
                                        Circle()
                                            .stroke(.quaternary, lineWidth: 1)
                                    }
                                
                                Image(systemName: secondaryButtonIcon)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.blue)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.isReachable || viewModel.isSending)
                        .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .scale.combined(with: .opacity)))
                    }
                    
                    // Main record button (double size, fully responsive)
                    Button(action: {
                        print("🎵 Watch button tapped - isRecording: \(viewModel.isRecording), isReachable: \(viewModel.isReachable), isSending: \(viewModel.isSending)")
                        
                        if viewModel.isRecording {
                            // Haptic feedback for stop
                            WKInterfaceDevice.current().play(.stop)
                            viewModel.stop()
                        } else {
                            // Haptic feedback for start
                            WKInterfaceDevice.current().play(.start)
                            viewModel.start()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(.regularMaterial)
                                .frame(width: 160, height: 160)
                                .overlay {
                                    Circle()
                                        .stroke(.quaternary.opacity(0.8), lineWidth: 2)
                                }
                            
                            Circle()
                                .fill(viewModel.isRecording ? 
                                      LinearGradient(colors: [.red.opacity(0.8), .red], startPoint: .top, endPoint: .bottom) : 
                                      LinearGradient(colors: [.blue.opacity(0.8), .blue], startPoint: .top, endPoint: .bottom))
                                .frame(width: 120, height: 120)
                                .overlay {
                                    Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundColor(.white)
                                }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contentShape(Circle())
                    .scaleEffect(viewModel.isRecording ? 0.95 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isRecording)
                    .scaleEffect(viewModel.isSending ? 0.9 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: viewModel.isSending)
                    .allowsHitTesting(!viewModel.isSending)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.isRecording)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
        .onAppear {
            viewModel.requestInitialStatus()
        }
    }
    
    // MARK: - Computed Properties
    
    private var connectionStatusText: String {
        if viewModel.isConnectivityActivated && viewModel.isReachable {
            return "Connected to iPhone"
        } else if viewModel.isConnectivityActivated {
            return "iPhone not reachable"
        } else {
            return "Connecting..."
        }
    }
    
    private var recordingStatusText: String {
        if viewModel.isPaused {
            return "Recording paused"
        } else if viewModel.isRecording {
            return "Recording..."
        } else {
            return "Tap to start recording"
        }
    }
    
    private var statusColor: Color {
        if !viewModel.isReachable {
            return .orange
        } else if viewModel.isSending {
            return .blue
        } else if viewModel.isRecording && !viewModel.isPaused {
            return .red
        } else if viewModel.isRecording && viewModel.isPaused {
            return .orange
        } else {
            return .secondary
        }
    }
    
    private var secondaryButtonIcon: String {
        if viewModel.isPaused {
            return "play.fill"
        } else {
            return "pause.fill"
        }
    }
    
    private var secondaryButtonText: String {
        if viewModel.isPaused {
            return "Resume"
        } else {
            return "Pause"
        }
    }
    
    // MARK: - Actions
    
    private func secondaryButtonAction() {
        if viewModel.isPaused {
            viewModel.resume()
        } else {
            viewModel.pause()
        }
    }
}

struct WatchHomeView_Previews: PreviewProvider {
    static var previews: some View {
        WatchHomeView()
    }
}
#endif



