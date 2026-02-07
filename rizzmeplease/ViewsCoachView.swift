//
//  CoachView.swift
//  TextCoach
//
//  View showing personalized insights and recommendations
//

import SwiftUI

struct CoachView: View {
    @EnvironmentObject var appState: AppState
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Group {
                if appState.coachInsightsUnlocked {
                    UnlockedCoachView(isLoading: $isLoading)
                } else {
                    LockedCoachView(
                        current: appState.feedbackProgress,
                        total: 5
                    )
                }
            }
            .navigationTitle("Coach")
            .toolbar {
                if appState.coachInsightsUnlocked {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: refreshInsights) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(isLoading)
                    }
                }
            }
        }
    }
    
    private func refreshInsights() {
        Task {
            isLoading = true
            try? await appState.fetchCoachInsights()
            isLoading = false
        }
    }
}

struct LockedCoachView: View {
    let current: Int
    let total: Int
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundStyle(.gray)
            
            Text("Coach Insights Locked")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Complete \(total) conversations with feedback to unlock personalized insights and patterns")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            VStack(spacing: 15) {
                ProgressView(value: Double(current), total: Double(total))
                    .tint(.blue)
                    .frame(maxWidth: 300)
                
                Text("\(current) of \(total) completed")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 10) {
                    ProgressCheckItem(
                        text: "Analyze conversations",
                        completed: true
                    )
                    ProgressCheckItem(
                        text: "Use a suggestion",
                        completed: current >= 1
                    )
                    ProgressCheckItem(
                        text: "Provide feedback on outcomes",
                        completed: current >= 1
                    )
                    ProgressCheckItem(
                        text: "Complete \(total) total",
                        completed: current >= total
                    )
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct ProgressCheckItem: View {
    let text: String
    let completed: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(completed ? .green : .gray)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(completed ? .primary : .secondary)
        }
    }
}

struct UnlockedCoachView: View {
    @EnvironmentObject var appState: AppState
    @Binding var isLoading: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.blue)
                        Text("Coach Insights Unlocked")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    Text("Based on your conversation history and feedback")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if let insights = appState.coachInsights {
                    // Stats Overview
                    StatsOverview(stats: insights.stats)
                        .padding(.horizontal)
                    
                    // Insights
                    if !insights.insights.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Your Patterns")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .padding(.horizontal)
                            
                            ForEach(insights.insights) { insight in
                                InsightCard(insight: insight)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Recommendations
                    if !insights.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Recommendations")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .padding(.horizontal)
                            
                            ForEach(insights.recommendations) { recommendation in
                                RecommendationCard(recommendation: recommendation)
                                    .padding(.horizontal)
                            }
                        }
                    }
                } else {
                    // No insights yet
                    VStack(spacing: 20) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        
                        Text("No Insights Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Check back after more conversations")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                }
            }
            .padding(.vertical)
        }
        .task {
            if appState.coachInsights == nil {
                isLoading = true
                try? await appState.fetchCoachInsights()
                isLoading = false
            }
        }
    }
}

struct StatsOverview: View {
    let stats: CoachAnalysisResponse.Stats
    
    var body: some View {
        VStack(spacing: 15) {
            HStack(spacing: 20) {
                StatBox(
                    value: "\(stats.totalConversations)",
                    label: "Total",
                    icon: "bubble.left.and.bubble.right"
                )
                
                StatBox(
                    value: "\(stats.totalFeedback)",
                    label: "With Feedback",
                    icon: "checkmark.circle"
                )
                
                StatBox(
                    value: "\(Int(stats.overallSuccessRate * 100))%",
                    label: "Success Rate",
                    icon: "chart.line.uptrend.xyaxis"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatBox: View {
    let value: String
    let label: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct InsightCard: View {
    let insight: CoachInsight
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(insight.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Text(insight.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(isExpanded ? nil : 2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Divider()
                
                if let goal = insight.data.goal {
                    Label(goal.displayName, systemImage: goal.icon)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .cornerRadius(8)
                }
                
                if let tone = insight.data.tone {
                    Label(tone.displayName, systemImage: tone.icon)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.1))
                        .foregroundStyle(.purple)
                        .cornerRadius(8)
                }
                
                if let successRate = insight.data.successRate,
                   let sampleSize = insight.data.sampleSize {
                    HStack {
                        Text("\(Int(successRate * 100))% success rate")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text("•")
                            .foregroundStyle(.secondary)
                        
                        Text("\(sampleSize) conversations")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
    }
}

struct RecommendationCard: View {
    let recommendation: CoachRecommendation
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: "lightbulb.fill")
                .font(.title2)
                .foregroundStyle(.yellow)
            
            Text(recommendation.text)
                .font(.subheadline)
            
            Spacer()
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    CoachView()
        .environmentObject(AppState())
}
