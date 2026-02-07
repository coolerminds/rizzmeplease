//
//  TextCoachApp.swift
//  TextCoach
//
//  AI-powered text message coach iOS application
//

import SwiftUI

@main
struct TextCoachApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authManager = AuthenticationManager()
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                MainTabView()
                    .environmentObject(appState)
                    .environmentObject(authManager)
            } else {
                OnboardingView()
                    .environmentObject(authManager)
                    .environmentObject(appState)
            }
        }
    }
}
