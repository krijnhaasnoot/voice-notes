#if os(watchOS)
import SwiftUI

struct WatchHomeView: View {
    @StateObject private var viewModel = WatchRecorderViewModel.shared
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 8) {
                // Status and connection info
                VStack(spacing: 4) {
                    Text(viewModel.statusText)
                        .font(.caption)
                        .foregroundColor(statusColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    if !viewModel.isReachable {
                        Text("Open iPhone app")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: 40)
                
                Spacer()
                
                // Main record button
                Button(action: mainButtonAction) {
                    ZStack {
                        Circle()
                            .fill(mainButtonColor)
                            .frame(width: buttonSize, height: buttonSize)
                        
                        Image(systemName: mainButtonIcon)
                            .font(.system(size: iconSize, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .disabled(!viewModel.isReachable || viewModel.isSending)
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(viewModel.isSending ? 0.9 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: viewModel.isSending)
                
                // Secondary action button (pause/resume)
                if viewModel.isRecording {
                    Button(action: secondaryButtonAction) {
                        HStack(spacing: 4) {
                            Image(systemName: secondaryButtonIcon)
                                .font(.caption)
                            Text(secondaryButtonText)
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                    }
                    .disabled(!viewModel.isReachable || viewModel.isSending)
                    .opacity(viewModel.isReachable && !viewModel.isSending ? 1.0 : 0.5)
                }
                
                Spacer()
                
                // Duration display
                Text(DurationFormatter.format(viewModel.duration))
                    .font(.system(.title3, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(height: 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .onAppear {
            viewModel.requestInitialStatus()
        }
    }
    
    // MARK: - Computed Properties
    
    private var buttonSize: CGFloat {
        80
    }
    
    private var iconSize: CGFloat {
        24
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
    
    private var mainButtonColor: Color {
        if viewModel.isRecording {
            return .red
        } else {
            return .blue
        }
    }
    
    private var mainButtonIcon: String {
        if viewModel.isRecording {
            return "stop.fill"
        } else {
            return "record.circle"
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
    
    private func mainButtonAction() {
        if viewModel.isRecording {
            viewModel.stop()
        } else {
            viewModel.start()
        }
    }
    
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