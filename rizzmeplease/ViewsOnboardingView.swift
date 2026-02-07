//
//  OnboardingView.swift
//  TextCoach
//
//  Initial onboarding and privacy consent
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var currentPage = 0
    
    var body: some View {
        TabView(selection: $currentPage) {
            WelcomePageView()
                .tag(0)
            
            PrivacyPageView()
                .tag(1)
            
            FeaturesPageView()
                .tag(2)
            
            GetStartedPageView {
                authManager.completeOnboarding()
            }
            .tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}

struct WelcomePageView: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "message.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            
            Text("Welcome to TextCoach")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("AI-powered help for better text conversations")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}

struct PrivacyPageView: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            
            Text("Your Privacy Matters")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 20) {
                PrivacyFeatureRow(
                    icon: "checkmark.shield.fill",
                    text: "Your conversations are encrypted"
                )
                
                PrivacyFeatureRow(
                    icon: "trash.fill",
                    text: "Delete your data anytime"
                )
                
                PrivacyFeatureRow(
                    icon: "eye.slash.fill",
                    text: "Optional local-only mode"
                )
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding()
    }
}

struct PrivacyFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 30)
            
            Text(text)
                .font(.body)
            
            Spacer()
        }
    }
}

struct FeaturesPageView: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Text("How It Works")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 25) {
                FeatureCard(
                    number: "1",
                    icon: "doc.on.clipboard",
                    title: "Paste Conversation",
                    description: "Share the text thread you need help with"
                )
                
                FeatureCard(
                    number: "2",
                    icon: "target",
                    title: "Choose Your Goal",
                    description: "Get a reply, ask for a meetup, or set boundaries"
                )
                
                FeatureCard(
                    number: "3",
                    icon: "sparkles",
                    title: "Get AI Suggestions",
                    description: "Receive 3 message options tailored to your style"
                )
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}

struct FeatureCard: View {
    let number: String
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text(number)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(.blue)
                    Text(title)
                        .font(.headline)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct GetStartedPageView: View {
    let onComplete: () -> Void
    @State private var agreedToTerms = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            
            Text("Ready to Get Started?")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Toggle(isOn: $agreedToTerms) {
                Text("I agree to the privacy policy and understand my conversations will be analyzed to provide suggestions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 30)
            .toggleStyle(SwitchToggleStyle(tint: .blue))
            
            Button(action: onComplete) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(agreedToTerms ? Color.blue : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(!agreedToTerms)
            .padding(.horizontal, 30)
            
            Spacer()
        }
        .padding()
    }
}
