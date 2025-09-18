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
            navBar.compactScrollEdgeAppearance = standardAppearance
        }
        
        // Additional styling
        navBar.isTranslucent = true
        navBar.tintColor = UIColor.systemBlue
        navBar.prefersLargeTitles = false // Let individual views control this
    }
}
