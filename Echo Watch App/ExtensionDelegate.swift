#if os(watchOS)
import WatchKit

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    
    func applicationDidFinishLaunching() {
        // Initialize the WatchConnectivityClient when the app launches
        _ = WatchConnectivityClient.shared
    }
    
    func applicationDidBecomeActive() {
        // Request fresh status when app becomes active
        WatchRecorderViewModel.shared.requestInitialStatus()
    }
    
    func applicationWillResignActive() {
        // Optional: handle app going to background
    }
}
#endif