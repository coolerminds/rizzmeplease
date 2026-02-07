//
//  MockDataService.swift
//  TextCoach
//
//  Mock data service for testing without backend
//

import Foundation

#if DEBUG
class MockDataService {
    static let shared = MockDataService()
    
    private init() {}
    
    // MARK: - Mock Suggestions
    
    func generateMockSuggestions(goal: Goal, tone: Tone) -> SuggestionResponse {
        let suggestions = getSuggestionsForGoalAndTone(goal: goal, tone: tone)
        
        return SuggestionResponse(
            conversationId: UUID().uuidString,
            suggestions: suggestions,
            metadata: SuggestionResponse.Metadata(
                generatedAt: ISO8601DateFormatter().string(from: Date()),
                modelVersion: "mock-v1.0"
            )
        )
    }
    
    private func getSuggestionsForGoalAndTone(goal: Goal, tone: Tone) -> [Suggestion] {
        switch (goal, tone) {
        case (.getReply, .friendly):
            return [
                Suggestion(
                    id: "s1",
                    text: "That sounds awesome! Tell me more about it 😊",
                    reasoning: "Friendly and enthusiastic response that encourages them to share more"
                ),
                Suggestion(
                    id: "s2",
                    text: "I'd love to hear more about that! What was your favorite part?",
                    reasoning: "Shows genuine interest while keeping the conversation flowing naturally"
                ),
                Suggestion(
                    id: "s3",
                    text: "Nice! How did you get into that?",
                    reasoning: "Casual question that opens up the conversation to deeper topics"
                )
            ]
            
        case (.getReply, .direct):
            return [
                Suggestion(
                    id: "s1",
                    text: "What happened next?",
                    reasoning: "Direct question that prompts a response"
                ),
                Suggestion(
                    id: "s2",
                    text: "I want to hear more. Can you explain?",
                    reasoning: "Clear expression of interest with a specific ask"
                ),
                Suggestion(
                    id: "s3",
                    text: "Tell me the details.",
                    reasoning: "Straightforward request that invites elaboration"
                )
            ]
            
        case (.getReply, .warm):
            return [
                Suggestion(
                    id: "s1",
                    text: "I can tell this means a lot to you. I'd love to understand more ❤️",
                    reasoning: "Empathetic response that validates their feelings"
                ),
                Suggestion(
                    id: "s2",
                    text: "Thank you for sharing that with me. How are you feeling about it?",
                    reasoning: "Shows appreciation and emotional awareness"
                ),
                Suggestion(
                    id: "s3",
                    text: "That sounds really meaningful. I'm here if you want to talk about it more.",
                    reasoning: "Supportive and creates emotional safety for continued conversation"
                )
            ]
            
        case (.getReply, .confident):
            return [
                Suggestion(
                    id: "s1",
                    text: "I'm interested. Let's keep talking about this.",
                    reasoning: "Direct statement of interest without hesitation"
                ),
                Suggestion(
                    id: "s2",
                    text: "Got it. What's your take on the situation?",
                    reasoning: "Shows you're engaged and confident in asking for their perspective"
                ),
                Suggestion(
                    id: "s3",
                    text: "Makes sense. I have thoughts on this too—what do you think about...?",
                    reasoning: "Confident in your own perspective while inviting dialogue"
                )
            ]
            
        case (.askMeetup, .friendly):
            return [
                Suggestion(
                    id: "s1",
                    text: "Hey, we should totally grab coffee sometime and chat more! ☕",
                    reasoning: "Casual and friendly meetup suggestion with low pressure"
                ),
                Suggestion(
                    id: "s2",
                    text: "This is fun! Want to continue this conversation over lunch this week?",
                    reasoning: "Frames meetup as continuation of existing positive interaction"
                ),
                Suggestion(
                    id: "s3",
                    text: "I'm enjoying this! Are you free to meet up sometime soon?",
                    reasoning: "Expresses enjoyment and makes a comfortable invitation"
                )
            ]
            
        case (.askMeetup, .direct):
            return [
                Suggestion(
                    id: "s1",
                    text: "Let's meet up. Are you free Thursday evening?",
                    reasoning: "Clear invitation with specific timeframe"
                ),
                Suggestion(
                    id: "s2",
                    text: "I'd like to take you to dinner. What's your schedule like this weekend?",
                    reasoning: "Straightforward intention with concrete ask"
                ),
                Suggestion(
                    id: "s3",
                    text: "Want to meet for drinks Friday? I know a great spot.",
                    reasoning: "Direct proposal with helpful suggestion"
                )
            ]
            
        case (.askMeetup, .warm):
            return [
                Suggestion(
                    id: "s1",
                    text: "I'm really enjoying getting to know you. Would you like to meet for coffee sometime? 💙",
                    reasoning: "Emotionally open while making a gentle invitation"
                ),
                Suggestion(
                    id: "s2",
                    text: "I feel like we'd have a great time in person. Would you be interested in meeting up?",
                    reasoning: "Expresses genuine connection and invites reciprocation"
                ),
                Suggestion(
                    id: "s3",
                    text: "I'd love to spend some time with you outside of text. Maybe dinner this week?",
                    reasoning: "Warm expression of desire to deepen connection"
                )
            ]
            
        case (.askMeetup, .confident):
            return [
                Suggestion(
                    id: "s1",
                    text: "Let's do this in person. I'm free Saturday—you?",
                    reasoning: "Confident and decisive with clear availability"
                ),
                Suggestion(
                    id: "s2",
                    text: "I think we should meet up. I'll take you to my favorite spot downtown.",
                    reasoning: "Shows initiative and decision-making without being pushy"
                ),
                Suggestion(
                    id: "s3",
                    text: "Texting is great, but I'd rather continue this face to face. When works for you?",
                    reasoning: "Confidently states preference while respecting their schedule"
                )
            ]
            
        case (.setBoundary, .friendly):
            return [
                Suggestion(
                    id: "s1",
                    text: "I appreciate you thinking of me, but I'm going to pass this time!",
                    reasoning: "Polite decline while maintaining friendly tone"
                ),
                Suggestion(
                    id: "s2",
                    text: "Thanks for the invite! I'm not able to make it, but I hope you have a great time 😊",
                    reasoning: "Gracious refusal with well-wishes"
                ),
                Suggestion(
                    id: "s3",
                    text: "That's really nice of you to ask, but I'm not going to be able to. Another time though!",
                    reasoning: "Acknowledges thoughtfulness while declining and leaving door open"
                )
            ]
            
        case (.setBoundary, .direct):
            return [
                Suggestion(
                    id: "s1",
                    text: "I'm not interested, but thanks for asking.",
                    reasoning: "Clear and respectful decline"
                ),
                Suggestion(
                    id: "s2",
                    text: "I need to be honest—this doesn't work for me.",
                    reasoning: "Direct honesty without over-explaining"
                ),
                Suggestion(
                    id: "s3",
                    text: "No, I'm not comfortable with that.",
                    reasoning: "Firm boundary stated clearly"
                )
            ]
            
        case (.setBoundary, .warm):
            return [
                Suggestion(
                    id: "s1",
                    text: "I really appreciate you, but I need to set a boundary here. I hope you understand ❤️",
                    reasoning: "Compassionate while maintaining clear limits"
                ),
                Suggestion(
                    id: "s2",
                    text: "I care about our relationship, which is why I need to be honest—I'm not comfortable with this.",
                    reasoning: "Frames boundary-setting as act of care and honesty"
                ),
                Suggestion(
                    id: "s3",
                    text: "Thank you for understanding. I need to prioritize my own needs right now, but I value you.",
                    reasoning: "Empathetic self-care while acknowledging the other person"
                )
            ]
            
        case (.setBoundary, .confident):
            return [
                Suggestion(
                    id: "s1",
                    text: "I'm not available for that. I hope you find what you're looking for.",
                    reasoning: "Assertive decline with respectful closure"
                ),
                Suggestion(
                    id: "s2",
                    text: "That doesn't align with what I'm looking for. I wish you the best.",
                    reasoning: "Confident in own needs while remaining respectful"
                ),
                Suggestion(
                    id: "s3",
                    text: "I've thought about it and I'm going to decline. Take care.",
                    reasoning: "Shows thoughtfulness and decisiveness"
                )
            ]
        }
    }
    
    // MARK: - Mock Coach Insights
    
    func generateMockCoachInsights(conversations: [Conversation]) -> CoachAnalysisResponse {
        let feedbackConversations = conversations.filter { $0.outcome != nil }
        let totalSuccess = feedbackConversations.filter { $0.outcome == .worked }.count
        let successRate = feedbackConversations.isEmpty ? 0.0 : Double(totalSuccess) / Double(feedbackConversations.count)
        
        return CoachAnalysisResponse(
            insights: [
                CoachInsight(
                    id: "i1",
                    category: "tone_effectiveness",
                    title: "Direct tone excels for meetup requests",
                    description: "Your direct approach has a higher success rate when transitioning to in-person meetups compared to other tones.",
                    data: CoachInsight.InsightData(
                        goal: .askMeetup,
                        tone: .direct,
                        successRate: 0.85,
                        sampleSize: 6
                    )
                ),
                CoachInsight(
                    id: "i2",
                    category: "message_length",
                    title: "Shorter messages get more replies",
                    description: "Messages under 50 characters in your history show a 20% higher response rate.",
                    data: CoachInsight.InsightData(
                        goal: nil,
                        tone: nil,
                        successRate: 0.75,
                        sampleSize: feedbackConversations.count
                    )
                ),
                CoachInsight(
                    id: "i3",
                    category: "goal_success",
                    title: "Strong at continuing conversations",
                    description: "Your 'Get Reply' goal has the highest success rate across all your conversations.",
                    data: CoachInsight.InsightData(
                        goal: .getReply,
                        tone: nil,
                        successRate: 0.80,
                        sampleSize: 10
                    )
                )
            ],
            recommendations: [
                CoachRecommendation(
                    id: "r1",
                    text: "Try 'Warm' tone for boundary-setting—it balances clarity with empathy.",
                    action: "experiment"
                ),
                CoachRecommendation(
                    id: "r2",
                    text: "Your friendly tone works well—consider using it more often for meetup requests.",
                    action: "increase_usage"
                )
            ],
            stats: CoachAnalysisResponse.Stats(
                totalConversations: conversations.count,
                totalFeedback: feedbackConversations.count,
                overallSuccessRate: successRate
            )
        )
    }
    
    // MARK: - Sample Conversations
    
    func getSampleConversation() -> Conversation {
        Conversation(
            messages: [
                Message(sender: .them, text: "Hey! How was your weekend?"),
                Message(sender: .you, text: "Pretty good! Went hiking with some friends."),
                Message(sender: .them, text: "Nice! Which trail did you do?"),
                Message(sender: .you, text: "Mount Tamalpais. The weather was perfect.")
            ],
            goal: .getReply,
            tone: .friendly,
            suggestions: [
                Suggestion(
                    id: "s1",
                    text: "The Ridge Trail! Have you been there?",
                    reasoning: "Specific answer with engaging follow-up question"
                ),
                Suggestion(
                    id: "s2",
                    text: "We did the coastal route—views were incredible!",
                    reasoning: "Enthusiastic detail that invites continued interest"
                ),
                Suggestion(
                    id: "s3",
                    text: "The one with all the redwoods. You should check it out sometime!",
                    reasoning: "Casual suggestion that opens door for future plans"
                )
            ]
        )
    }
}

// MARK: - Mock API Service Extension

extension APIService {
    func generateSuggestionsWithMock(messages: [Message], goal: Goal, tone: Tone) async throws -> SuggestionResponse {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        return MockDataService.shared.generateMockSuggestions(goal: goal, tone: tone)
    }
    
    func submitFeedbackWithMock(conversationId: String, suggestionId: String, outcome: Outcome, notes: String?) async throws -> FeedbackResponse {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        return FeedbackResponse(
            feedbackId: UUID().uuidString,
            recordedAt: ISO8601DateFormatter().string(from: Date()),
            coachInsightsReady: true
        )
    }
    
    func fetchCoachInsightsWithMock(conversations: [Conversation]) async throws -> CoachAnalysisResponse {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        return MockDataService.shared.generateMockCoachInsights(conversations: conversations)
    }
}
#endif
