#if os(watchOS)
import SwiftUI
import WatchKit

struct WatchDiagnosticsView: View {
    @ObservedObject private var connectivityClient = WatchConnectivityClient.shared
    @State private var showingPingResult = false

    private var pingResultText: String {
        if let pingTime = connectivityClient.lastPingTime,
           let pongTime = connectivityClient.lastPongTime,
           pongTime > pingTime {
            let f = DateFormatter(); f.dateFormat = "mm:ss"
            return "Last: \(f.string(from: pingTime)) → \(f.string(from: pongTime))\nLatency: \(connectivityClient.latencyMs)ms"
        } else if connectivityClient.lastPingTime != nil {
            return "Ping sent, waiting for pong..."
        } else {
            return "No ping test yet"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WatchConnectivity").font(.system(.title3, weight: .bold))
                    Text("Diagnostics").font(.system(.caption, weight: .medium)).foregroundColor(.secondary)
                }.padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Connection Status")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.bottom, 4)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        StatusRow(label: "Activated", value: connectivityClient.isActivated ? "✅" : "❌")
                        StatusRow(label: "Paired", value: connectivityClient.isPaired ? "✅" : "❌")
                        StatusRow(label: "Reachable", value: connectivityClient.isReachable ? "✅" : "❌")
                        StatusRow(label: "iPhone App", value: connectivityClient.isCompanionAppInstalled ? "✅ Installed" : "❌ Missing")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(8)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Ping Test")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.bottom, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(pingResultText)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)

                        Button("Send Ping") {
                            connectivityClient.sendPing()
                            showingPingResult = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { showingPingResult = false }
                        }
                        .font(.system(.caption, weight: .medium))
                        .foregroundColor(.blue)
                        .disabled(!connectivityClient.isActivated)
                        
                        Button("Run Diagnostics") {
                            connectivityClient.diagnoseConnectionIssue()
                        }
                        .font(.system(.caption, weight: .medium))
                        .foregroundColor(.orange)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(8)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Bundle Info")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.bottom, 4)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bundle ID:").font(.system(.caption2, weight: .medium)).foregroundColor(.secondary)
                        Text(Bundle.main.bundleIdentifier ?? "unknown")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(8)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Test Commands")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.bottom, 4)
                    
                    VStack(spacing: 6) {
                        Button("Request Status") { connectivityClient.sendCommand("requestStatus") }
                            .font(.system(.caption, weight: .medium)).foregroundColor(.blue)
                        Button("Test Start Record") { connectivityClient.sendCommand("startRecording") }
                            .font(.system(.caption, weight: .medium)).foregroundColor(.green)
                        Button("Test Stop Record") { connectivityClient.sendCommand("stopRecording") }
                            .font(.system(.caption, weight: .medium)).foregroundColor(.red)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(8)
                    .disabled(!connectivityClient.isActivated)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
}

struct StatusRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.system(.caption2)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(.caption2, weight: .medium))
        }
    }
}

#Preview { WatchDiagnosticsView() }
#endif

