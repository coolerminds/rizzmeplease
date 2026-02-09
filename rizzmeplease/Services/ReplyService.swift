import Foundation

protocol ReplyService {
    func generateReplies(request: ReplyRequest) async throws -> ReplyResponse
}

protocol DemoHistoryProviding {
    func fetchDemoHistory() async throws -> [DemoHistoryRecord]
}

struct DemoHistoryRecord: Identifiable, Equatable {
    let id: String
    let vibe: Vibe
    let relationship: Relationship
    let context: String
    let transcript: String
    let reply: String
    let createdAt: Date
}

enum BackendReplyServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingFailed
    case invalidTranscript
    case httpError(statusCode: Int, code: String?, message: String)
    case transport(Error)

    var statusCode: Int? {
        switch self {
        case .httpError(let statusCode, _, _):
            return statusCode
        default:
            return nil
        }
    }

    var isTransportFailure: Bool {
        switch self {
        case .transport, .invalidResponse, .invalidURL:
            return true
        case .httpError(let statusCode, _, _):
            return statusCode >= 500 || statusCode == 408
        default:
            return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL configuration."
        case .invalidResponse:
            return "Invalid response from server."
        case .decodingFailed:
            return "Unable to decode API response."
        case .invalidTranscript:
            return "Transcript must contain at least two message lines."
        case .httpError(let statusCode, _, let message):
            return "HTTP \(statusCode): \(message)"
        case .transport(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

struct GrokConfig {
    static let apiKey: String? = Bundle.main.object(forInfoDictionaryKey: "GROK_API_KEY") as? String
    static let endpoint = URL(string: "https://api.x.ai/v1/chat/completions")!
    static let model = "grok-beta"
}

actor BackendReplyService: ReplyService, DemoHistoryProviding {
    private let session: URLSession
    private let baseURLProvider: @Sendable () -> URL
    private let tokenKey = "rizzcoach_access_token"
    private let tokenCreatedAtKey = "rizzcoach_access_token_created_at"

    init(
        session: URLSession = .shared,
        baseURLProvider: @escaping @Sendable () -> URL = { AppRuntimeConfig.apiBaseURL }
    ) {
        self.session = session
        self.baseURLProvider = baseURLProvider
    }

    func generateReplies(request: ReplyRequest) async throws -> ReplyResponse {
        let token = try await accessToken(forceRefresh: false)

        do {
            return try await performGenerate(request: request, token: token)
        } catch let error as BackendReplyServiceError where error.statusCode == 401 {
            let refreshedToken = try await accessToken(forceRefresh: true)
            return try await performGenerate(request: request, token: refreshedToken)
        }
    }

    func fetchDemoHistory() async throws -> [DemoHistoryRecord] {
        var urlRequest = URLRequest(url: currentBaseURL().appendingPathComponent("history/demo"))
        urlRequest.httpMethod = "GET"

        let (data, response) = try await perform(request: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendReplyServiceError.invalidResponse
        }

        if httpResponse.statusCode >= 400 {
            throw decodeAPIError(data: data, statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        do {
            let envelope = try decoder.decode(DemoHistoryEnvelope.self, from: data)
            return envelope.data.items.compactMap { item in
                guard let vibe = Vibe(rawValue: item.vibe),
                      let relationship = Relationship(rawValue: item.relationship) else {
                    return nil
                }

                return DemoHistoryRecord(
                    id: item.id,
                    vibe: vibe,
                    relationship: relationship,
                    context: item.context,
                    transcript: item.transcript,
                    reply: item.reply,
                    createdAt: item.createdAt
                )
            }
        } catch {
            throw BackendReplyServiceError.decodingFailed
        }
    }

    private func performGenerate(request: ReplyRequest, token: String) async throws -> ReplyResponse {
        let messages = parseTranscript(request.transcript)
        if messages.count < 2 {
            throw BackendReplyServiceError.invalidTranscript
        }

        var urlRequest = URLRequest(url: currentBaseURL().appendingPathComponent("suggestions"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")

        let body = SuggestionRequestBody(
            conversation: .init(messages: messages),
            goal: mapGoal(request.vibe),
            tone: mapTone(request.vibe),
            relationshipType: mapRelationship(request.relationship),
            context: request.context.isEmpty ? nil : request.context,
            threadContext: nil
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(body)

        let (data, response) = try await perform(request: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendReplyServiceError.invalidResponse
        }

        if httpResponse.statusCode >= 400 {
            throw decodeAPIError(data: data, statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        do {
            let envelope = try decoder.decode(SuggestionResponseEnvelope.self, from: data)
            let drafts = envelope.data.suggestions.enumerated().map { index, suggestion in
                ReplyDraft(
                    id: UUID(),
                    text: suggestion.text,
                    vibe: request.vibe,
                    relationship: request.relationship,
                    createdAt: .now.addingTimeInterval(Double(index))
                )
            }
            return ReplyResponse(drafts: drafts)
        } catch {
            throw BackendReplyServiceError.decodingFailed
        }
    }

    private func perform(request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw BackendReplyServiceError.transport(error)
        }
    }

    private func accessToken(forceRefresh: Bool) async throws -> String {
        let defaults = UserDefaults.standard
        if !forceRefresh,
           let token = defaults.string(forKey: tokenKey),
           let createdAt = defaults.object(forKey: tokenCreatedAtKey) as? Date,
           Date().timeIntervalSince(createdAt) < 23 * 60 * 60 {
            return token
        }

        var urlRequest = URLRequest(url: currentBaseURL().appendingPathComponent("auth/anonymous"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = AuthRequest(deviceId: UUID().uuidString)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(body)

        let (data, response) = try await perform(request: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendReplyServiceError.invalidResponse
        }

        if httpResponse.statusCode >= 400 {
            throw decodeAPIError(data: data, statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            let envelope = try decoder.decode(AuthResponseEnvelope.self, from: data)
            defaults.set(envelope.data.accessToken, forKey: tokenKey)
            defaults.set(Date(), forKey: tokenCreatedAtKey)
            return envelope.data.accessToken
        } catch {
            throw BackendReplyServiceError.decodingFailed
        }
    }

    private func parseTranscript(_ transcript: String) -> [SuggestionRequestBody.ConversationData.MessageData] {
        let iso8601 = ISO8601DateFormatter()
        let lines = transcript
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let messages = lines.prefix(50).map { line -> SuggestionRequestBody.ConversationData.MessageData in
            let lowercased = line.lowercased()
            if lowercased.hasPrefix("you:") {
                return .init(
                    sender: "you",
                    text: String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces),
                    timestamp: iso8601.string(from: Date())
                )
            }
            if lowercased.hasPrefix("them:") {
                return .init(
                    sender: "them",
                    text: String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces),
                    timestamp: iso8601.string(from: Date())
                )
            }
            return .init(
                sender: "them",
                text: line,
                timestamp: iso8601.string(from: Date())
            )
        }

        if messages.count < 2 {
            return []
        }
        return messages
    }

    private func currentBaseURL() -> URL {
        baseURLProvider()
    }

    private func mapTone(_ vibe: Vibe) -> String {
        switch vibe {
        case .flirty:
            return "warm"
        case .smooth:
            return "friendly"
        case .bold:
            return "confident"
        case .classy:
            return "direct"
        case .funny:
            return "friendly"
        case .chill:
            return "warm"
        }
    }

    private func mapRelationship(_ relationship: Relationship) -> String {
        switch relationship {
        case .crush:
            return "dating"
        case .friend:
            return "friend"
        case .work:
            return "professional"
        case .dating:
            return "dating"
        }
    }

    private func mapGoal(_ vibe: Vibe) -> String {
        // Keep MVP flow anchored to reply generation for the RizzCoach UI.
        _ = vibe
        return "get_reply"
    }

    private func decodeAPIError(data: Data, statusCode: Int) -> BackendReplyServiceError {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        if let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data) {
            if let detail = envelope.error ?? envelope.detail {
                return .httpError(
                    statusCode: statusCode,
                    code: detail.code,
                    message: detail.message
                )
            }
        }

        return .httpError(statusCode: statusCode, code: nil, message: "Request failed")
    }
}

struct GrokReplyService: ReplyService {
    let apiKey: String
    let endpoint: URL
    let model: String

    init(apiKey: String, endpoint: URL = GrokConfig.endpoint, model: String = GrokConfig.model) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.model = model
    }

    func generateReplies(request: ReplyRequest) async throws -> ReplyResponse {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let prompt = """
        You are RizzCoach, crafting concise, warm SMS replies. Keep it short (1-2 sentences), match vibe \(request.vibe.title), relationship \(request.relationship.title), context: "\(request.context)". Conversation: \(request.transcript)
        Provide 3 distinct reply options separated by newline.
        """

        let body = GrokRequest(
            model: model,
            messages: [
                .init(role: "user", content: prompt)
            ],
            max_tokens: 120,
            temperature: 0.7
        )

        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw BackendReplyServiceError.httpError(statusCode: 502, code: "GROK_ERROR", message: "Grok request failed")
        }

        let decoded = try JSONDecoder().decode(GrokResponse.self, from: data)
        let content = decoded.choices.first?.message.content ?? ""
        let lines = content
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let texts = lines.isEmpty ? [content] : Array(lines.prefix(3))
        let drafts = texts.enumerated().map { idx, line in
            ReplyDraft(
                id: UUID(),
                text: line,
                vibe: request.vibe,
                relationship: request.relationship,
                createdAt: .now.addingTimeInterval(Double(idx))
            )
        }
        return ReplyResponse(drafts: drafts)
    }

    private struct GrokRequest: Encodable {
        struct GrokMessage: Encodable {
            let role: String
            let content: String
        }
        let model: String
        let messages: [GrokMessage]
        let max_tokens: Int?
        let temperature: Double?
    }

    private struct GrokResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String
            }
            let message: Message
        }
        let choices: [Choice]
    }
}

struct MockReplyService: ReplyService {
    func generateReplies(request: ReplyRequest) async throws -> ReplyResponse {
        let seed = "\(request.vibe.rawValue)-\(request.relationship.rawValue)"
        let base = mockLines(seed: seed)
        let drafts = base.enumerated().map { idx, line in
            ReplyDraft(
                id: UUID(),
                text: line,
                vibe: request.vibe,
                relationship: request.relationship,
                createdAt: .now.addingTimeInterval(Double(idx))
            )
        }
        return ReplyResponse(drafts: drafts)
    }

    private func mockLines(seed: String) -> [String] {
        switch seed {
        case _ where seed.contains("flirty"):
            return [
                "I like where this is going. Want to keep the vibe rolling?",
                "This sounds fun. What are you thinking next?",
                "Let us make this happen. I am in."
            ]
        case _ where seed.contains("smooth"):
            return [
                "Love the energy. Want to lock in a time?",
                "This could be great. How does tomorrow evening look?",
                "I am into it. Let us pick a spot."
            ]
        case _ where seed.contains("bold"):
            return [
                "Let us do it. Are you free tonight?",
                "I am game. Name the time and place.",
                "I like decisive plans. Want to set it now?"
            ]
        case _ where seed.contains("classy"):
            return [
                "That sounds lovely. Shall we plan something this weekend?",
                "I would enjoy that. What day works best for you?",
                "Consider me interested. Let us coordinate."
            ]
        case _ where seed.contains("funny"):
            return [
                "I am in, as long as there are snacks. Deal?",
                "That sounds fun. Should I bring my best jokes too?",
                "Count me in. Do I need to rehearse a comedy set?"
            ]
        case _ where seed.contains("chill"):
            return [
                "Sounds good. Want to keep it low-key?",
                "I am down. Maybe something simple like coffee?",
                "Let us keep it easy. When are you free?"
            ]
        default:
            return [
                "I am interested. Tell me more.",
                "Let us figure out timing.",
                "Sounds promising. What is next?"
            ]
        }
    }
}

private struct SuggestionRequestBody: Encodable {
    struct ConversationData: Encodable {
        struct MessageData: Encodable {
            let sender: String
            let text: String
            let timestamp: String
        }

        let messages: [MessageData]
    }

    let conversation: ConversationData
    let goal: String
    let tone: String
    let relationshipType: String?
    let context: String?
    let threadContext: ConversationData?
}

private struct SuggestionResponseEnvelope: Decodable {
    let success: Bool
    let data: SuggestionData

    struct SuggestionData: Decodable {
        let suggestionSetId: String
        let suggestions: [SuggestionItem]
        let conversationId: String
        let createdAt: Date
    }

    struct SuggestionItem: Decodable {
        let id: String
        let rank: Int
        let text: String
        let rationale: String
        let confidenceScore: Double?
    }
}

private struct AuthRequest: Encodable {
    let deviceId: String
}

private struct AuthResponseEnvelope: Decodable {
    let success: Bool
    let data: AuthData

    struct AuthData: Decodable {
        let accessToken: String
        let tokenType: String
        let userId: String
    }
}

private struct APIErrorEnvelope: Decodable {
    let detail: APIErrorDetail?
    let error: APIErrorDetail?

    struct APIErrorDetail: Decodable {
        let code: String?
        let message: String
    }
}

private struct DemoHistoryEnvelope: Decodable {
    let success: Bool
    let data: DemoHistoryData

    struct DemoHistoryData: Decodable {
        let items: [DemoHistoryItem]
    }

    struct DemoHistoryItem: Decodable {
        let id: String
        let vibe: String
        let relationship: String
        let context: String
        let transcript: String
        let reply: String
        let createdAt: Date
    }
}
