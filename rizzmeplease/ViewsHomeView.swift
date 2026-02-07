//
//  HomeView.swift
//  TextCoach
//
//  Main home screen with new analysis CTA and recent history
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingNewAnalysis = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
                    // Header
                    VStack(spacing: 10) {
                        Text("TextCoach")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Get AI-powered help for your text conversations")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Main CTA
                    Button(action: { showingNewAnalysis = true }) {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.title2)
                            
                            VStack(alignment: .leading) {
                                Text("Analyze Conversation")
                                    .font(.headline)
                                Text("Get AI suggestions for your next message")
                                    .font(.caption)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundStyle(.white)
                        .cornerRadius(16)
                        .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
                    }
                    .padding(.horizontal)
                    
                    // Recent History
                    if !appState.conversations.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Text("Recent Conversations")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            ForEach(Array(appState.conversations.prefix(3))) { conversation in
                                NavigationLink(destination: ConversationDetailView(conversation: conversation)) {
                                    RecentConversationCard(conversation: conversation)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    // Coach Insights Teaser
                    if appState.coachInsightsUnlocked {
                        CoachInsightsTeaserCard()
                            .padding(.horizontal)
                    } else {
                        CoachProgressCard(
                            current: appState.feedbackProgress,
                            total: 5
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 30)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingNewAnalysis) {
                NewAnalysisFlow()
            }
        }
    }
}

struct RecentConversationCard: View {
    let conversation: Conversation
    
    var body: some View {
        HStack(spacing: 15) {
            // Goal Icon
            ZStack {
                Circle()
                    .fill(goalColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: conversation.goal?.icon ?? "questionmark")
                    .foregroundStyle(goalColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if let goal = conversation.goal {
                        Text(goal.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    if let tone = conversation.tone {
                        Text("• \(tone.displayName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text(conversation.preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if let outcome = conversation.outcome {
                    Image(systemName: outcome.icon)
                        .foregroundStyle(outcomeColor(outcome))
                }
                
                Text(conversation.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var goalColor: Color {
        switch conversation.goal {
        case .getReply: return .blue
        case .askMeetup: return .purple
        case .setBoundary: return .orange
        case .none: return .gray
        }
    }
    
    private func outcomeColor(_ outcome: Outcome) -> Color {
        switch outcome {
        case .worked: return .green
        case .noResponse: return .gray
        case .negative: return .red
        }
    }
}

struct CoachInsightsTeaserCard: View {
    var body: some View {
        HStack {
            Image(systemName: "lightbulb.fill")
                .font(.title)
                .foregroundStyle(.yellow)
            
            VStack(alignment: .leading) {
                Text("New Insights Available")
                    .font(.headline)
                Text("Check your Coach tab for patterns")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemYellow).opacity(0.1))
        .cornerRadius(12)
    }
}

struct CoachProgressCard: View {
    let current: Int
    let total: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.gray)
                Text("Unlock Coach Insights")
                    .font(.headline)
            }
            
            Text("Complete \(total - current) more conversations with feedback")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            ProgressView(value: Double(current), total: Double(total))
                .tint(.blue)
            
            Text("\(current) of \(total) conversations completed")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
