#if os(watchOS)
import SwiftUI

struct WatchMainView: View {
    var body: some View {
        TabView {
            // Main recording interface
            WatchHomeView()
                .tabItem {
                    Image(systemName: "mic.fill")
                    Text("Record")
                }
                .tag(0)
            
            // Diagnostics interface
            WatchDiagnosticsView()
                .tabItem {
                    Image(systemName: "wifi")
                    Text("Diagnostics")
                }
                .tag(1)
        }
        .tabViewStyle(.page)
    }
}

#Preview {
    WatchMainView()
}
#endif