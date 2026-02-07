//
//  NewAnalysisFlow.swift
//  TextCoach
//
//  Multi-step flow for creating a new conversation analysis
//

import SwiftUI

struct NewAnalysisFlow: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var currentStep: AnalysisStep = .paste
    @State private var conversationText = ""
    @State private var parsedMessages: [Message] = []
    @State private var selectedGoal: Goal?
    @State private var selectedTone: Tone?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    
    enum AnalysisStep {
        case paste
        case goalTone
        case suggestions
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                switch currentStep {
                case .paste:
                    PasteConversationView(
                        conversationText: $conversationText,
                        parsedMessages: $parsedMessages,
                        onNext: {
                            currentStep = .goalTone
                        }
                    )
                    
                case .goalTone:
                    GoalTonePickerView(
                        selectedGoal: $selectedGoal,
                        selectedTone: $selectedTone,
                        onGenerate: {
                            await generateSuggestions()
                        }
                    )
                    
                case .suggestions:
                    if let conversation = appState.currentConversation {
                        SuggestionsView(conversation: conversation, onDismiss: {
                            dismiss()
                        })
                    }
                }
                
                if isGenerating {
                    LoadingOverlay()
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if currentStep == .goalTone {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { currentStep = .paste }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                        }
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    private var navigationTitle: String {
        switch currentStep {
        case .paste: return "New Analysis"
        case .goalTone: return "Choose Goal & Tone"
        case .suggestions: return "Suggestions"
        }
    }
    
    private func generateSuggestions() async {
        guard let goal = selectedGoal, let tone = selectedTone else { return }
        
        isGenerating = true
        appState.startNewConversation(messages: parsedMessages)
        appState.updateConversationGoalAndTone(goal: goal, tone: tone)
        
        do {
            try await appState.generateSuggestions()
            currentStep = .suggestions
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isGenerating = false
    }
}

// MARK: - Paste Conversation View

struct PasteConversationView: View {
    @Binding var conversationText: String
    @Binding var parsedMessages: [Message]
    let onNext: () -> Void
    
    @State private var showingPreview = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Instructions
                Text("Paste your conversation")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Copy and paste the text conversation you need help with. We'll automatically detect who said what.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                // Text Editor
                TextEditor(text: $conversationText)
                    .frame(minHeight: 300)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .onChange(of: conversationText) { _, newValue in
                        parseConversation(newValue)
                    }
                
                if conversationText.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Example format:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        Text("""
                        Them: Hey, how was your weekend?
                        You: Pretty good! Went hiking.
                        Them: Nice! Which trail?
                        """)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                
                // Auto-detect from clipboard
                Button(action: pasteFromClipboard) {
                    Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                }
                
                // Preview
                if !parsedMessages.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Detected \(parsedMessages.count) messages")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Button(showingPreview ? "Hide Preview" : "Show Preview") {
                                showingPreview.toggle()
                            }
                            .font(.caption)
                        }
                        
                        if showingPreview {
                            VStack(spacing: 8) {
                                ForEach(parsedMessages) { message in
                                    MessagePreviewRow(message: message)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGreen).opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Next Button
                Button(action: onNext) {
                    Text("Next")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canProceed ? Color.blue : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(!canProceed)
            }
            .padding()
        }
    }
    
    private var canProceed: Bool {
        parsedMessages.count >= 2 && parsedMessages.count <= 50
    }
    
    private func pasteFromClipboard() {
        #if os(iOS)
        if let clipboardText = UIPasteboard.general.string {
            conversationText = clipboardText
        }
        #endif
    }
    
    private func parseConversation(_ text: String) {
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var messages: [Message] = []
        
        for line in lines {
            // Try to detect "You:" or "Them:" prefixes
            if line.lowercased().hasPrefix("you:") {
                let text = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                messages.append(Message(sender: .you, text: text))
            } else if line.lowercased().hasPrefix("them:") {
                let text = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                messages.append(Message(sender: .them, text: text))
            } else if line.lowercased().hasPrefix("me:") {
                let text = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                messages.append(Message(sender: .you, text: text))
            } else {
                // Alternate if no prefix detected
                let sender: MessageSender = messages.isEmpty ? .them : (messages.last?.sender == .you ? .them : .you)
                messages.append(Message(sender: sender, text: line))
            }
        }
        
        parsedMessages = messages
    }
}

struct MessagePreviewRow: View {
    let message: Message
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(message.sender == .you ? "You" : "Them")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(message.sender == .you ? .blue : .purple)
                .frame(width: 50, alignment: .leading)
            
            Text(message.text)
                .font(.caption)
                .foregroundStyle(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("Generating suggestions...")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(30)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }
}

#Preview {
    NewAnalysisFlow()
        .environmentObject(AppState())
}
