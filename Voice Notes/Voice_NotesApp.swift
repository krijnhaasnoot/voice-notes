//
//  Voice_NotesApp.swift
//  Voice Notes
//
//  Created by Krijn Haasnoot on 06/09/2025.
//

import SwiftUI
import Foundation
import AVFoundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

@main
struct Voice_NotesApp: App {
    @StateObject private var documentStore = DocumentStore()
    @StateObject private var usageViewModel = UsageViewModel.shared

    init() {
        // Initialize singletons immediately
        let recorder = AudioRecorder.shared
        let manager = RecordingsManager.shared
        
        print("📱 APP: Voice Notes app starting...")
        print("📱 APP: Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print("📱 APP: Singletons initialized")
        
        // Ensure WC manager is initialized and wired immediately at app startup
        #if canImport(WatchConnectivity)
        let bridge = WatchConnectivityManager.shared
        bridge.setAudioRecorder(recorder)
        bridge.setRecordingsManager(manager)
        print("📱 APP: WatchConnectivity manager initialized and wired")
        
        // Run connection diagnostics after a brief delay to allow activation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            bridge.diagnoseConnectionIssue()
        }
        #endif
        
        configureLiquidNavigationBar()
        
        // Initialize telemetry session
        Task { @MainActor in
            EnhancedTelemetryService.shared.startSession(reason: "cold")
        }
        
        // Initialize analytics with session management
        initializeAnalytics()
        
        // Register background tasks for processing
        BackgroundTaskManager.shared.registerBackgroundTasks()
        
        print("📱 APP: App initialization complete")
    }
    
    var body: some Scene {
        WindowGroup {
            AnimatedSplashView()
                .environmentObject(documentStore)
                .environmentObject(AudioRecorder.shared)
                .environmentObject(RecordingsManager.shared)
                .environmentObject(usageViewModel)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    handleAppDidBecomeActive()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    handleAppDidEnterBackground()
                }
        }
    }
    
    // MARK: - Analytics Session Management
    
    private func initializeAnalytics() {
        // Start analytics with static session provider
        Analytics.start {
            return SessionManager.shared.getCurrentSessionId()
        }
        
        // Track app launch
        Analytics.track("app_open")
    }
    
    private func handleAppDidBecomeActive() {
        // Refresh session and track app open
        let currentSessionId = SessionManager.shared.getCurrentSessionId()
        Analytics.track("app_open")
        print("📊 Analytics: App became active, session: \(currentSessionId)")

        // Refresh usage quota
        Task { @MainActor in
            await usageViewModel.refresh()
        }
    }
    
    private func handleAppDidEnterBackground() {
        // Track app background and flush events
        Analytics.track("app_background")
        Analytics.flush()
        print("📊 Analytics: App entered background, flushed events")
    }
    
    private func configureLiquidNavigationBar() {
        // Configure navigation bar appearance for standard/compact states (small title)
        let standardAppearance = UINavigationBarAppearance()
        standardAppearance.configureWithTransparentBackground()
        standardAppearance.backgroundColor = UIColor.clear
        standardAppearance.shadowColor = UIColor.clear
        standardAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        
        // Configure navigation bar appearance for large title states
        let largeTitleAppearance = UINavigationBarAppearance()
        largeTitleAppearance.configureWithDefaultBackground()
        largeTitleAppearance.backgroundColor = UIColor.systemBackground
        largeTitleAppearance.shadowColor = UIColor.clear
        
        // Configure text colors for both appearances
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        let largeTitleAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        
        standardAppearance.titleTextAttributes = titleAttributes
        standardAppearance.largeTitleTextAttributes = largeTitleAttributes
        largeTitleAppearance.titleTextAttributes = titleAttributes  
        largeTitleAppearance.largeTitleTextAttributes = largeTitleAttributes
        
        // Apply to all navigation bar states
        let navBar = UINavigationBar.appearance()
        navBar.standardAppearance = standardAppearance
        navBar.compactAppearance = standardAppearance
        navBar.scrollEdgeAppearance = largeTitleAppearance
        if #available(iOS 15.0, *) {
            navBar.compactScrollEdgeAppearance = largeTitleAppearance
        }
        
        // Additional styling
        navBar.isTranslucent = true
        navBar.tintColor = UIColor.systemBlue
        navBar.prefersLargeTitles = true // Enable large titles globally
    }
}
