//
//  SuggestionsView.swift
//  TextCoach
//
//  View displaying AI-generated message suggestions
//

import SwiftUI

struct SuggestionsView: View {
    @EnvironmentObject var appState: AppState
    let conversation: Conversation
    let onDismiss: () -> Void
    
    @State private var copiedSuggestionId: String?
    @State private var showingFeedbackSheet = false
    @State private var expandedReasoningId: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
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
                    
                    Text("Here are 3 suggestions")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                // Suggestions
                ForEach(Array(conversation.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                    SuggestionCard(
                        suggestion: suggestion,
                        number: index + 1,
                        isCopied: copiedSuggestionId == suggestion.id,
                        isExpanded: expandedReasoningId == suggestion.id,
                        onCopy: {
                            copySuggestion(suggestion)
                        },
                        onToggleReasoning: {
                            withAnimation {
                                expandedReasoningId = expandedReasoningId == suggestion.id ? nil : suggestion.id
                            }
                        }
                    )
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    if conversation.usedSuggestionId != nil {
                        Button(action: { showingFeedbackSheet = true }) {
                            Text("How Did It Go?")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(12)
                        }
                    }
                    
                    Button(action: {
                        Task {
                            try? await appState.regenerateSuggestions()
                        }
                    }) {
                        Label("Regenerate Suggestions", systemImage: "arrow.clockwise")
                            .font(.headline)
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    Button(action: onDismiss) {
                        Text("Done")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingFeedbackSheet) {
            if let suggestionId = conversation.usedSuggestionId {
                FeedbackSheet(
                    conversationId: conversation.id,
                    suggestionId: suggestionId,
                    onDismiss: {
                        showingFeedbackSheet = false
                        onDismiss()
                    }
                )
            }
        }
    }
    
    private func copySuggestion(_ suggestion: Suggestion) {
        #if os(iOS)
        UIPasteboard.general.string = suggestion.text
        #endif
        
        copiedSuggestionId = suggestion.id
        appState.markSuggestionUsed(suggestionId: suggestion.id)
        
        // Reset copied state after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copiedSuggestionId == suggestion.id {
                copiedSuggestionId = nil
            }
        }
    }
}

struct SuggestionCard: View {
    let suggestion: Suggestion
    let number: Int
    let isCopied: Bool
    let isExpanded: Bool
    let onCopy: () -> Void
    let onToggleReasoning: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Option \(number)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(suggestion.charCount) characters")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            // Suggestion Text
            Text(suggestion.text)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            // Reasoning (Expandable)
            Button(action: onToggleReasoning) {
                HStack {
                    Text("Why this works")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(.blue)
            }
            
            if isExpanded {
                Text(suggestion.reasoning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
            }
            
            // Copy Button
            Button(action: onCopy) {
                HStack {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    Text(isCopied ? "Copied!" : "Copy to Clipboard")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isCopied ? Color.green : Color.blue)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Feedback Sheet

struct FeedbackSheet: View {
    @EnvironmentObject var appState: AppState
    let conversationId: UUID
    let suggestionId: String
    let onDismiss: () -> Void
    
    @State private var selectedOutcome: Outcome?
    @State private var notes = ""
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 25) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    
                    Text("How did it go?")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Help us improve your suggestions")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 30)
                
                // Outcome Buttons
                VStack(spacing: 15) {
                    ForEach([Outcome.worked, Outcome.noResponse, Outcome.negative], id: \.self) { outcome in
                        OutcomeButton(
                            outcome: outcome,
                            isSelected: selectedOutcome == outcome,
                            action: { selectedOutcome = outcome }
                        )
                    }
                }
                
                // Optional Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Any notes? (optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextEditor(text: $notes)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
                
                Spacer()
                
                // Submit Button
                Button(action: submitFeedback) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isSubmitting ? "Submitting..." : "Submit Feedback")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedOutcome != nil ? Color.blue : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(selectedOutcome == nil || isSubmitting)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private func submitFeedback() {
        guard let outcome = selectedOutcome else { return }
        
        Task {
            isSubmitting = true
            do {
                try await appState.submitFeedback(
                    outcome: outcome,
                    notes: notes.isEmpty ? nil : notes
                )
                onDismiss()
            } catch {
                // Handle error
                print("Failed to submit feedback: \(error)")
            }
            isSubmitting = false
        }
    }
}

struct OutcomeButton: View {
    let outcome: Outcome
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: outcome.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : outcomeColor)
                    .frame(width: 40)
                
                Text(outcome.displayName)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : .primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .background(isSelected ? outcomeColor : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var outcomeColor: Color {
        switch outcome {
        case .worked: return .green
        case .noResponse: return .gray
        case .negative: return .red
        }
    }
}

#Preview {
    let conversation = Conversation(
        messages: [],
        goal: .getReply,
        tone: .friendly,
        suggestions: [
            Suggestion(id: "1", text: "I did the Ridge Trail at Mount Tamalpais! Have you been?", reasoning: "Answers their question with specificity"),
            Suggestion(id: "2", text: "Mount Tam! The views were incredible. Do you hike often?", reasoning: "Shows enthusiasm"),
            Suggestion(id: "3", text: "Ridge Trail near the city—totally worth it!", reasoning: "Casual and friendly")
        ]
    )
    
    SuggestionsView(conversation: conversation, onDismiss: {})
        .environmentObject(AppState())
}
