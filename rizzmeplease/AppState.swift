//
//  AppState.swift
//  TextCoach
//
//  Central state management for the application
//

import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?
    @Published var coachInsights: CoachAnalysisResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var localOnlyMode = false
    
    private let apiService: APIService
    private let storageService: StorageService
    
    init(apiService: APIService = APIService.shared,
         storageService: StorageService = StorageService.shared) {
        self.apiService = apiService
        self.storageService = storageService
        loadLocalData()
    }
    
    // MARK: - Conversation Management
    
    func startNewConversation(messages: [Message]) {
        let conversation = Conversation(messages: messages)
        currentConversation = conversation
    }
    
    func updateConversationGoalAndTone(goal: Goal, tone: Tone) {
        currentConversation?.goal = goal
        currentConversation?.tone = tone
    }
    
    func generateSuggestions() async throws {
        guard var conversation = currentConversation,
              let goal = conversation.goal,
              let tone = conversation.tone else {
            throw AppError.invalidConversation
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Use mock data for MVP testing
            #if DEBUG
            let response = try await apiService.generateSuggestionsWithMock(
                messages: conversation.messages,
                goal: goal,
                tone: tone
            )
            #else
            let response = try await apiService.generateSuggestions(
                messages: conversation.messages,
                goal: goal,
                tone: tone
            )
            #endif
            
            conversation.suggestions = response.suggestions
            currentConversation = conversation
            
            // Save locally
            conversations.insert(conversation, at: 0)
            saveLocalData()
            
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func regenerateSuggestions() async throws {
        try await generateSuggestions()
    }
    
    func markSuggestionUsed(suggestionId: String) {
        currentConversation?.usedSuggestionId = suggestionId
        if let index = conversations.firstIndex(where: { $0.id == currentConversation?.id }) {
            conversations[index].usedSuggestionId = suggestionId
            saveLocalData()
        }
    }
    
    func submitFeedback(outcome: Outcome, notes: String?) async throws {
        guard let conversation = currentConversation,
              let suggestionId = conversation.usedSuggestionId else {
            throw AppError.noSuggestionUsed
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Use mock data for MVP testing
            #if DEBUG
            let response = try await apiService.submitFeedbackWithMock(
                conversationId: conversation.id.uuidString,
                suggestionId: suggestionId,
                outcome: outcome,
                notes: notes
            )
            #else
            let response = try await apiService.submitFeedback(
                conversationId: conversation.id.uuidString,
                suggestionId: suggestionId,
                outcome: outcome,
                notes: notes
            )
            #endif
            
            // Update local conversation
            if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
                conversations[index].outcome = outcome
                conversations[index].feedbackNotes = notes
                conversations[index].feedbackAt = Date()
                saveLocalData()
            }
            
            // Check if coach insights are ready
            if response.coachInsightsReady {
                try await fetchCoachInsights()
            }
            
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - History
    
    func fetchHistory() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await apiService.fetchHistory()
            // Merge with local conversations
            // For MVP, we prioritize local storage
            saveLocalData()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func deleteConversation(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
        if currentConversation?.id == conversation.id {
            currentConversation = nil
        }
        saveLocalData()
    }
    
    // MARK: - Coach Insights
    
    func fetchCoachInsights() async throws {
        let feedbackCount = conversations.filter { $0.outcome != nil }.count
        guard feedbackCount >= 5 else {
            throw AppError.insufficientFeedback(current: feedbackCount, required: 5)
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Use mock data for MVP testing
            #if DEBUG
            let insights = try await apiService.fetchCoachInsightsWithMock(conversations: conversations)
            #else
            let insights = try await apiService.fetchCoachInsights()
            #endif
            coachInsights = insights
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    var coachInsightsUnlocked: Bool {
        conversations.filter { $0.outcome != nil }.count >= 5
    }
    
    var feedbackProgress: Int {
        min(conversations.filter { $0.outcome != nil }.count, 5)
    }
    
    // MARK: - Data Management
    
    func deleteAllData() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await apiService.deleteUserData()
            conversations.removeAll()
            currentConversation = nil
            coachInsights = nil
            storageService.clearAll()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Local Storage
    
    private func loadLocalData() {
        conversations = storageService.loadConversations()
        localOnlyMode = storageService.loadLocalOnlyMode()
    }
    
    private func saveLocalData() {
        storageService.saveConversations(conversations)
    }
    
    func toggleLocalOnlyMode() {
        localOnlyMode.toggle()
        storageService.saveLocalOnlyMode(localOnlyMode)
    }
}

// MARK: - Errors

enum AppError: LocalizedError {
    case invalidConversation
    case noSuggestionUsed
    case insufficientFeedback(current: Int, required: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidConversation:
            return "Please provide a valid conversation with goal and tone selected."
        case .noSuggestionUsed:
            return "Please mark a suggestion as used before submitting feedback."
        case .insufficientFeedback(let current, let required):
            return "You need \(required - current) more conversations with feedback to unlock Coach Insights."
        }
    }
}
