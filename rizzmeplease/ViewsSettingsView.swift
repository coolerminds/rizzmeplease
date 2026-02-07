//
//  SettingsView.swift
//  TextCoach
//
//  Settings and privacy controls
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showingDeleteConfirmation = false
    @State private var showingLogoutConfirmation = false
    @State private var isDeleting = false
    
    var body: some View {
        NavigationStack {
            List {
                // Privacy Section
                Section {
                    Toggle(isOn: $appState.localOnlyMode) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Local-Only Mode")
                                .font(.body)
                            Text("Disable AI features and keep all data on device")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: appState.localOnlyMode) { _, _ in
                        appState.toggleLocalOnlyMode()
                    }
                    
                    Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                        Label("Delete All My Data", systemImage: "trash")
                    }
                    
                    NavigationLink(destination: PrivacyPolicyView()) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Local-only mode disables AI suggestions and stores all data on your device only. Your data is encrypted and never shared with third parties.")
                }
                
                // Account Section
                Section("Account") {
                    HStack {
                        Text("Email")
                        Spacer()
                        Text("demo@textcoach.app")
                            .foregroundStyle(.secondary)
                    }
                    
                    Button(action: { showingLogoutConfirmation = true }) {
                        Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
                
                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    Link(destination: URL(string: "mailto:support@textcoach.app")!) {
                        Label("Send Feedback", systemImage: "envelope")
                    }
                    
                    Link(destination: URL(string: "https://apps.apple.com/app/textcoach")!) {
                        Label("Rate on App Store", systemImage: "star")
                    }
                }
                
                // Data Section
                Section {
                    HStack {
                        Text("Conversations Stored")
                        Spacer()
                        Text("\(appState.conversations.count)")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Feedback Provided")
                        Spacer()
                        Text("\(appState.conversations.filter { $0.outcome != nil }.count)")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Your Data")
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Delete All Data",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete All My Data", role: .destructive) {
                    deleteAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your conversations, feedback, and insights. This action cannot be undone.")
            }
            .confirmationDialog(
                "Logout",
                isPresented: $showingLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Logout", role: .destructive) {
                    Task {
                        await authManager.logout()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to logout?")
            }
            .overlay {
                if isDeleting {
                    LoadingOverlay()
                }
            }
        }
    }
    
    private func deleteAllData() {
        Task {
            isDeleting = true
            do {
                try await appState.deleteAllData()
                await authManager.logout()
            } catch {
                print("Failed to delete data: \(error)")
            }
            isDeleting = false
        }
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy Policy")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Last updated: February 6, 2026")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Divider()
                
                PolicySection(
                    title: "Data Collection",
                    content: "TextCoach collects conversation text you choose to share for analysis. We use this data to generate AI-powered suggestions and improve your experience."
                )
                
                PolicySection(
                    title: "Data Usage",
                    content: "Your conversation data is used exclusively to:\n• Generate message suggestions\n• Analyze patterns for Coach insights\n• Improve suggestion quality over time"
                )
                
                PolicySection(
                    title: "Data Security",
                    content: "All data is encrypted both in transit (TLS 1.3) and at rest (AES-256). We never share your conversations with third parties for marketing or other purposes."
                )
                
                PolicySection(
                    title: "Your Rights",
                    content: "You can:\n• Enable local-only mode to keep all data on device\n• Delete all your data at any time\n• Export your data (contact support@textcoach.app)\n• Opt out of data collection entirely"
                )
                
                PolicySection(
                    title: "AI Provider",
                    content: "We use OpenAI's API for generating suggestions. OpenAI does not store your data beyond 30 days for abuse monitoring. See OpenAI's privacy policy for details."
                )
                
                PolicySection(
                    title: "Data Retention",
                    content: "We retain your data until you choose to delete it. Conversations can be automatically deleted after 90 days if you enable this option in settings."
                )
                
                PolicySection(
                    title: "Contact",
                    content: "For privacy questions or data requests, contact privacy@textcoach.app"
                )
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PolicySection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            Text(content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
        .environmentObject(AuthenticationManager())
}
