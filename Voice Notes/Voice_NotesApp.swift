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
    
    var body: some Scene {
        WindowGroup {
            AnimatedSplashView()
                .environmentObject(documentStore)
        }
    }
}
