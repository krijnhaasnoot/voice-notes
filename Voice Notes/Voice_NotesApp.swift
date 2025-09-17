//
//  Voice_NotesApp.swift
//  Voice Notes
//
//  Created by Krijn Haasnoot on 06/09/2025.
//

import SwiftUI

@main
struct Voice_NotesApp: App {
    @StateObject private var documentStore = DocumentStore()
    
    init() {
        configureLiquidNavigationBar()
    }
    
    var body: some Scene {
        WindowGroup {
            AnimatedSplashView()
                .environmentObject(documentStore)
        }
    }
    
    private func configureLiquidNavigationBar() {
        // Configure navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithTransparentBackground()
        navBarAppearance.backgroundColor = UIColor.clear
        navBarAppearance.shadowColor = UIColor.clear
        
        // Create a stronger blur effect
        navBarAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        
        // Configure text colors
        navBarAppearance.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navBarAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        
        // Apply to all navigation bar states
        let navBar = UINavigationBar.appearance()
        navBar.standardAppearance = navBarAppearance
        navBar.compactAppearance = navBarAppearance
        navBar.scrollEdgeAppearance = navBarAppearance
        if #available(iOS 15.0, *) {
            navBar.compactScrollEdgeAppearance = navBarAppearance
        }
        
        // Additional styling
        navBar.isTranslucent = true
        navBar.barTintColor = UIColor.clear
        navBar.tintColor = UIColor.systemBlue
    }
}
