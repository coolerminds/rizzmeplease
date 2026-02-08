import Foundation
import SwiftData

protocol ReplyService {
    func generateReplies(request: ReplyRequest) async throws -> ReplyResponse
}

struct MockReplyService: ReplyService {
    func generateReplies(request: ReplyRequest) async throws -> ReplyResponse {
        // Deterministic mock based on vibe + relationship for predictable previews/tests.
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
