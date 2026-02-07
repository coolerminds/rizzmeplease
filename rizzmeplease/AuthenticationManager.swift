//
//  AuthenticationManager.swift
//  TextCoach
//
//  Manages user authentication state
//

import Foundation
import SwiftUI

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var hasCompletedOnboarding = false
    
    init() {
        // Check for existing token
        if let _ = try? KeychainService.shared.getToken() {
            isAuthenticated = true
        }
        
        // Check onboarding status
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "has_completed_onboarding")
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "has_completed_onboarding")
        
        // For MVP, we'll use a mock token
        // In production, this would come from actual auth
        try? KeychainService.shared.saveToken("mock_token_for_mvp")
        isAuthenticated = true
    }
    
    func logout() async {
        try? KeychainService.shared.deleteToken()
        isAuthenticated = false
    }
}
