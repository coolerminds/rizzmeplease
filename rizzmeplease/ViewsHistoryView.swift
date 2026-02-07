//
//  HistoryView.swift
//  TextCoach
//
//  View showing all past conversation analyses
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedFilter: FilterOption = .all
    
    enum FilterOption: String, CaseIterable {
        case all = "All"
        case withFeedback = "With Feedback"
        case pending = "Pending"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(FilterOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                if filteredConversations.isEmpty {
                    EmptyHistoryView()
                } else {
                    List {
                        ForEach(filteredConversations) { conversation in
                            NavigationLink(destination: ConversationDetailView(conversation: conversation)) {
                                HistoryRow(conversation: conversation)
                            }
                        }
                        .onDelete(perform: deleteConversations)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search conversations")
        }
    }
    
    private var filteredConversations: [Conversation] {
        var conversations = appState.conversations
        
        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .withFeedback:
            conversations = conversations.filter { $0.outcome != nil }
        case .pending:
            conversations = conversations.filter { $0.usedSuggestionId != nil && $0.outcome == nil }
        }
        
        // Apply search
        if !searchText.isEmpty {
            conversations = conversations.filter { conversation in
                conversation.preview.localizedCaseInsensitiveContains(searchText) ||
                conversation.goal?.displayName.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
        
        return conversations
    }
    
    private func deleteConversations(at offsets: IndexSet) {
        for index in offsets {
            let conversation = filteredConversations[index]
            appState.deleteConversation(conversation)
        }
    }
}

struct HistoryRow: View {
    let conversation: Conversation
    
    var body: some View {
        HStack(spacing: 15) {
            // Goal Icon
            ZStack {
                Circle()
                    .fill(goalColor.opacity(0.2))
                    .frame(width: 45, height: 45)
                
                Image(systemName: conversation.goal?.icon ?? "questionmark")
                    .foregroundStyle(goalColor)
            }
            
            VStack(alignment: .leading, spacing: 6) {
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
                
                HStack {
                    Text(conversation.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    if let outcome = conversation.outcome {
                        Image(systemName: outcome.icon)
                            .font(.caption2)
                            .foregroundStyle(outcomeColor(outcome))
                    } else if conversation.usedSuggestionId != nil {
                        Text("Pending feedback")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
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

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Conversations Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start analyzing conversations to see your history here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Conversation Detail View

struct ConversationDetailView: View {
    @EnvironmentObject var appState: AppState
    let conversation: Conversation
    @State private var showingFeedbackSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                // Metadata
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        if let goal = conversation.goal {
                            Label(goal.displayName, systemImage: goal.icon)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .cornerRadius(8)
                        }
                        
                        if let tone = conversation.tone {
                            Label(tone.displayName, systemImage: tone.icon)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.purple.opacity(0.1))
                                .foregroundStyle(.purple)
                                .cornerRadius(8)
                        }
                    }
                    
                    Text(conversation.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Original Conversation
                VStack(alignment: .leading, spacing: 10) {
                    Text("Original Conversation")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        ForEach(conversation.messages) { message in
                            ConversationBubble(message: message)
                        }
                    }
                }
                
                // Suggestions
                VStack(alignment: .leading, spacing: 10) {
                    Text("Suggestions")
                        .font(.headline)
                    
                    ForEach(conversation.suggestions) { suggestion in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(suggestion.text)
                                    .font(.body)
                                
                                if conversation.usedSuggestionId == suggestion.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                conversation.usedSuggestionId == suggestion.id ?
                                Color.green.opacity(0.1) : Color(.systemGray6)
                            )
                            .cornerRadius(8)
                        }
                    }
                }
                
                // Outcome
                if let outcome = conversation.outcome {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Outcome")
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: outcome.icon)
                                .foregroundStyle(outcomeColor(outcome))
                            Text(outcome.displayName)
                                .font(.subheadline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(outcomeColor(outcome).opacity(0.1))
                        .cornerRadius(8)
                        
                        if let notes = conversation.feedbackNotes, !notes.isEmpty {
                            Text(notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                } else if conversation.usedSuggestionId != nil {
                    Button(action: { showingFeedbackSheet = true }) {
                        Text("Add Feedback")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingFeedbackSheet) {
            if let suggestionId = conversation.usedSuggestionId {
                FeedbackSheet(
                    conversationId: conversation.id,
                    suggestionId: suggestionId,
                    onDismiss: { showingFeedbackSheet = false }
                )
            }
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

struct ConversationBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.sender == .you {
                Spacer()
            }
            
            VStack(alignment: message.sender == .you ? .trailing : .leading, spacing: 4) {
                Text(message.sender.displayName)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(message.sender == .you ? .blue : .purple)
                
                Text(message.text)
                    .font(.body)
                    .padding(12)
                    .background(message.sender == .you ? Color.blue.opacity(0.1) : Color.purple.opacity(0.1))
                    .cornerRadius(16)
            }
            .frame(maxWidth: 280, alignment: message.sender == .you ? .trailing : .leading)
            
            if message.sender == .them {
                Spacer()
            }
        }
    }
}

#Preview {
    HistoryView()
        .environmentObject(AppState())
}
