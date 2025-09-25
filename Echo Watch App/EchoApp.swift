//
//  EchoApp.swift
//  Echo Watch App
//
//  Created by Krijn Haasnoot on 21/09/2025.
//

import SwiftUI
import WatchKit

@main
struct Echo_Watch_AppApp: App {
    init() {
        print("⌚ APP: Echo Watch App starting...")
        print("⌚ APP: Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        
        // Initialize WatchConnectivity immediately at app startup
        let client = WatchConnectivityClient.shared
        print("⌚ APP: WatchConnectivity client initialized")
        
        // Run connection diagnostics after a brief delay to allow activation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            client.diagnoseConnectionIssue()
        }
        
        print("⌚ APP: Watch app initialization complete")
    }
    
    var body: some Scene {
        WindowGroup {
            WatchMainView()
        }
    }
}

