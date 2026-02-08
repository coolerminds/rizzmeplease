import Foundation
import SwiftData

protocol ReplyService {
    func generateReplies(request: ReplyRequest) async throws -> ReplyResponse
}

struct GrokConfig {
    static let apiKey: String? = Bundle.main.object(forInfoDictionaryKey: "GROK_API_KEY") as? String
    static let endpoint = URL(string: "https://api.x.ai/v1/chat/completions")!
    static let model = "grok-beta"
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
        You are RizzCoach, crafting concise, warm SMS replies. Keep it short (1–2 sentences), match the vibe \(request.vibe.title), relationship \(request.relationship.title), context: "\(request.context)". Conversation: \(request.transcript)
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
            throw GrokError.badStatus
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

    enum GrokError: Error {
        case badStatus
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
                "I like where this is going—want to keep the vibe rolling?",
                "This sounds fun. What are you thinking next?",
                "Let’s make this happen, I’m in."
            ]
        case _ where seed.contains("smooth"):
            return [
                "Love the energy—want to firm up a time?",
                "This could be great. How does tomorrow evening look?",
                "I’m into it. Let’s pick a spot."
            ]
        case _ where seed.contains("bold"):
            return [
                "Let’s just do it. Are you free tonight?",
                "I’m game. Name the time and place.",
                "I like decisive plans—want to set it now?"
            ]
        case _ where seed.contains("classy"):
            return [
                "That sounds lovely. Shall we plan something this weekend?",
                "I’d enjoy that. What day works best for you?",
                "Consider me interested—let’s coordinate."
            ]
        case _ where seed.contains("funny"):
            return [
                "I’m in, as long as there’s snacks. Deal?",
                "That sounds fun—should I bring my best jokes too?",
                "Count me in. Do I need to rehearse a comedy set?"
            ]
        case _ where seed.contains("chill"):
            return [
                "Sounds good. Want to keep it low-key?",
                "I’m down. Maybe something simple like coffee?",
                "Let’s keep it easy—when are you free?"
            ]
        default:
            return [
                "I’m interested—tell me more.",
                "Let’s figure out timing.",
                "Sounds promising. What’s next?"
            ]
        }
    }
}
