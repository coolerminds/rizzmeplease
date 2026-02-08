//
//  APIService.swift
//  TextCoach
//
//  Handles all backend API communication
//

import Foundation

class APIService {
    static let shared = APIService()
    
    private let baseURL = AppRuntimeConfig.apiBaseURLString
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    // MARK: - Suggestions
    
    func generateSuggestions(messages: [Message], goal: Goal, tone: Tone) async throws -> SuggestionResponse {
        let request = makeSuggestionRequest(
            messages: messages,
            goal: goal,
            tone: tone
        )
        
        return try await post(endpoint: "/suggestions", body: request)
    }
    
    func generateThreadSuggestions(
        messages: [Message],
        goal: Goal,
        tone: Tone,
        relationshipType: RelationshipType?,
        extraContext: String?,
        threadContext: [Message]
    ) async throws -> SuggestionResponse {
        let request = makeSuggestionRequest(
            messages: messages,
            goal: goal,
            tone: tone,
            relationshipType: relationshipType,
            context: extraContext,
            threadContext: threadContext
        )
        
        return try await post(endpoint: "/suggestions", body: request)
    }
    
    // MARK: - Feedback
    
    func submitFeedback(conversationId: String, suggestionId: String, outcome: Outcome, notes: String?) async throws -> FeedbackResponse {
        let request = FeedbackRequest(
            conversationId: conversationId,
            suggestionId: suggestionId,
            outcome: outcome.rawValue,
            notes: notes
        )
        
        return try await post(endpoint: "/feedback", body: request)
    }
    
    // MARK: - History
    
    func fetchHistory(limit: Int = 20, offset: Int = 0) async throws -> HistoryResponse {
        let queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        
        return try await get(endpoint: "/history", queryItems: queryItems)
    }
    
    // MARK: - Coach
    
    func fetchCoachInsights() async throws -> CoachAnalysisResponse {
        let request = ["min_conversations": 5]
        return try await post(endpoint: "/coach/analyze", body: request)
    }
    
    // MARK: - User Data
    
    func deleteUserData() async throws {
        let request = ["confirmation": "DELETE_MY_DATA"]
        let _: EmptyResponse = try await delete(endpoint: "/user/data", body: request)
    }
    
    // MARK: - Generic Request Methods

    private func makeSuggestionRequest(
        messages: [Message],
        goal: Goal,
        tone: Tone,
        relationshipType: RelationshipType? = nil,
        context: String? = nil,
        threadContext: [Message] = []
    ) -> SuggestionRequest {
        let iso8601 = ISO8601DateFormatter()
        let conversation = SuggestionRequest.ConversationData(
            messages: messages.map { message in
                SuggestionRequest.ConversationData.MessageData(
                    sender: message.sender.rawValue,
                    text: message.text,
                    timestamp: iso8601.string(from: message.timestamp)
                )
            }
        )
        
        let encodedThreadContext: SuggestionRequest.ConversationData? =
            threadContext.isEmpty
            ? nil
            : SuggestionRequest.ConversationData(
                messages: threadContext.map { message in
                    SuggestionRequest.ConversationData.MessageData(
                        sender: message.sender.rawValue,
                        text: message.text,
                        timestamp: iso8601.string(from: message.timestamp)
                    )
                }
            )
        
        return SuggestionRequest(
            conversation: conversation,
            goal: goal.rawValue,
            tone: tone.rawValue,
            relationshipType: relationshipType?.rawValue,
            context: context,
            threadContext: encodedThreadContext
        )
    }

    private func get<T: Decodable>(endpoint: String, queryItems: [URLQueryItem] = []) async throws -> T {
        var components = URLComponents(string: baseURL + endpoint)!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        try addAuthHeaders(to: &request)
        
        return try await perform(request: request)
    }
    
    private func post<T: Encodable, R: Decodable>(endpoint: String, body: T) async throws -> R {
        var request = URLRequest(url: URL(string: baseURL + endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        try addAuthHeaders(to: &request)
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)
        
        return try await perform(request: request)
    }
    
    private func delete<T: Encodable, R: Decodable>(endpoint: String, body: T) async throws -> R {
        var request = URLRequest(url: URL(string: baseURL + endpoint)!)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try addAuthHeaders(to: &request)
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)
        
        return try await perform(request: request)
    }
    
    private func perform<T: Decodable>(request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        // Check for errors
        if httpResponse.statusCode >= 400 {
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw apiError
            }
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(T.self, from: data)
    }
    
    private func addAuthHeaders(to request: inout URLRequest) throws {
        // Get token from keychain
        if let token = try? KeychainService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
}

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "Server error (code: \(code))"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

// Empty response for delete operations
struct EmptyResponse: Codable {}
