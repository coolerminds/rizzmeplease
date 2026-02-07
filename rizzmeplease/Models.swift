//
//  Models.swift
//  TextCoach
//
//  Core data models for the application
//

import Foundation

// MARK: - Enums

enum Goal: String, Codable, CaseIterable {
    case getReply = "get_reply"
    case askMeetup = "ask_meetup"
    case setBoundary = "set_boundary"
    
    var displayName: String {
        switch self {
        case .getReply: return "Get Reply"
        case .askMeetup: return "Ask for Meetup"
        case .setBoundary: return "Set Boundary"
        }
    }
    
    var subtitle: String {
        switch self {
        case .getReply: return "Keep the conversation going"
        case .askMeetup: return "Transition to in-person"
        case .setBoundary: return "Politely decline or establish limits"
        }
    }
    
    var icon: String {
        switch self {
        case .getReply: return "bubble.left.and.bubble.right"
        case .askMeetup: return "calendar"
        case .setBoundary: return "hand.raised"
        }
    }
}

enum Tone: String, Codable, CaseIterable {
    case friendly
    case direct
    case warm
    case confident
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .friendly: return "face.smiling"
        case .direct: return "arrow.right.circle"
        case .warm: return "heart"
        case .confident: return "star"
        }
    }
    
    var description: String {
        switch self {
        case .friendly: return "Casual, warm, approachable"
        case .direct: return "Clear, straightforward"
        case .warm: return "Empathetic, emotionally attuned"
        case .confident: return "Self-assured, decisive"
        }
    }
}

enum Outcome: String, Codable {
    case worked
    case noResponse = "no_response"
    case negative
    
    var displayName: String {
        switch self {
        case .worked: return "Worked"
        case .noResponse: return "No Response"
        case .negative: return "Negative"
        }
    }
    
    var icon: String {
        switch self {
        case .worked: return "checkmark.circle.fill"
        case .noResponse: return "clock.fill"
        case .negative: return "xmark.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .worked: return "green"
        case .noResponse: return "gray"
        case .negative: return "red"
        }
    }
}

// MARK: - Message Models

struct Message: Identifiable, Codable, Equatable {
    let id: UUID
    var sender: MessageSender
    var text: String
    var timestamp: Date
    
    init(id: UUID = UUID(), sender: MessageSender, text: String, timestamp: Date = Date()) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
    }
}

enum MessageSender: String, Codable {
    case you
    case them
    
    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Conversation

struct Conversation: Identifiable, Codable {
    let id: UUID
    var messages: [Message]
    var goal: Goal?
    var tone: Tone?
    var suggestions: [Suggestion]
    var usedSuggestionId: String?
    var outcome: Outcome?
    var feedbackNotes: String?
    var createdAt: Date
    var feedbackAt: Date?
    
    init(id: UUID = UUID(),
         messages: [Message] = [],
         goal: Goal? = nil,
         tone: Tone? = nil,
         suggestions: [Suggestion] = [],
         usedSuggestionId: String? = nil,
         outcome: Outcome? = nil,
         feedbackNotes: String? = nil,
         createdAt: Date = Date(),
         feedbackAt: Date? = nil) {
        self.id = id
        self.messages = messages
        self.goal = goal
        self.tone = tone
        self.suggestions = suggestions
        self.usedSuggestionId = usedSuggestionId
        self.outcome = outcome
        self.feedbackNotes = feedbackNotes
        self.createdAt = createdAt
        self.feedbackAt = feedbackAt
    }
    
    var preview: String {
        guard !messages.isEmpty else { return "Empty conversation" }
        let first = messages.prefix(2).map { $0.text }.joined(separator: " ")
        return String(first.prefix(60)) + (first.count > 60 ? "..." : "")
    }
    
    var isComplete: Bool {
        outcome != nil
    }
}

// MARK: - Suggestion

struct Suggestion: Identifiable, Codable, Equatable {
    let id: String
    let text: String
    let reasoning: String
    let charCount: Int
    
    init(id: String, text: String, reasoning: String, charCount: Int? = nil) {
        self.id = id
        self.text = text
        self.reasoning = reasoning
        self.charCount = charCount ?? text.count
    }
}

// MARK: - API Models

struct SuggestionRequest: Codable {
    struct ConversationData: Codable {
        struct MessageData: Codable {
            let sender: String
            let text: String
            let timestamp: String
        }
        let messages: [MessageData]
    }
    
    let conversation: ConversationData
    let goal: String
    let tone: String
}

struct SuggestionResponse: Codable {
    let conversationId: String
    let suggestions: [Suggestion]
    let metadata: Metadata
    
    struct Metadata: Codable {
        let generatedAt: String
        let modelVersion: String
        
        enum CodingKeys: String, CodingKey {
            case generatedAt = "generated_at"
            case modelVersion = "model_version"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case suggestions
        case metadata
    }
}

struct FeedbackRequest: Codable {
    let conversationId: String
    let suggestionId: String
    let outcome: String
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case suggestionId = "suggestion_id"
        case outcome
        case notes
    }
}

struct FeedbackResponse: Codable {
    let feedbackId: String
    let recordedAt: String
    let coachInsightsReady: Bool
    
    enum CodingKeys: String, CodingKey {
        case feedbackId = "feedback_id"
        case recordedAt = "recorded_at"
        case coachInsightsReady = "coach_insights_ready"
    }
}

// MARK: - History

struct HistoryItem: Identifiable, Codable {
    let conversationId: String
    let goal: Goal
    let tone: Tone
    let preview: String
    let outcome: Outcome?
    let createdAt: Date
    let feedbackAt: Date?
    
    var id: String { conversationId }
    
    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case goal
        case tone
        case preview
        case outcome
        case createdAt = "created_at"
        case feedbackAt = "feedback_at"
    }
}

struct HistoryResponse: Codable {
    let items: [HistoryItem]
    let pagination: Pagination
    
    struct Pagination: Codable {
        let total: Int
        let limit: Int
        let offset: Int
        let next: String?
    }
}

// MARK: - Coach Insights

struct CoachInsight: Identifiable, Codable {
    let id: String
    let category: String
    let title: String
    let description: String
    let data: InsightData
    
    struct InsightData: Codable {
        let goal: Goal?
        let tone: Tone?
        let successRate: Double?
        let sampleSize: Int?
        
        enum CodingKeys: String, CodingKey {
            case goal
            case tone
            case successRate = "success_rate"
            case sampleSize = "sample_size"
        }
    }
}

struct CoachRecommendation: Identifiable, Codable {
    let id: String
    let text: String
    let action: String
}

struct CoachAnalysisResponse: Codable {
    let insights: [CoachInsight]
    let recommendations: [CoachRecommendation]
    let stats: Stats
    
    struct Stats: Codable {
        let totalConversations: Int
        let totalFeedback: Int
        let overallSuccessRate: Double
        
        enum CodingKeys: String, CodingKey {
            case totalConversations = "total_conversations"
            case totalFeedback = "total_feedback"
            case overallSuccessRate = "overall_success_rate"
        }
    }
}

// MARK: - Error Response

struct APIError: Codable, LocalizedError {
    let error: ErrorDetail
    
    struct ErrorDetail: Codable {
        let code: String
        let message: String
        let details: [String: AnyCodable]?
    }
    
    var errorDescription: String? {
        error.message
    }
}

// Helper for decoding dynamic JSON
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            value = ""
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        }
    }
}
