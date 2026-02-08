import SwiftUI
import SwiftData

enum Vibe: String, CaseIterable, Identifiable {
    case flirty, smooth, bold, classy, funny, chill
    var id: String { rawValue }
    var title: String {
        switch self {
        case .flirty: return "Flirty"
        case .smooth: return "Smooth"
        case .bold: return "Bold"
        case .classy: return "Classy"
        case .funny: return "Funny"
        case .chill: return "Chill"
        }
    }
    var emoji: String {
        switch self {
        case .flirty: return "😉"
        case .smooth: return "😎"
        case .bold: return "🔥"
        case .classy: return "💎"
        case .funny: return "😂"
        case .chill: return "🧊"
        }
    }
    var color: Color {
        switch self {
        case .flirty: return RZColor.flirty
        case .smooth: return RZColor.smooth
        case .bold: return RZColor.bold
        case .classy: return RZColor.classy
        case .funny: return RZColor.funny
        case .chill: return RZColor.chill
        }
    }
}

enum Relationship: String, CaseIterable, Identifiable {
    case crush, friend, work, dating
    var id: String { rawValue }
    var title: String {
        switch self {
        case .crush: return "Crush"
        case .friend: return "Friend"
        case .work: return "Work"
        case .dating: return "Dating"
        }
    }
    var emoji: String {
        switch self {
        case .crush: return "💘"
        case .friend: return "👥"
        case .work: return "💼"
        case .dating: return "❤️"
        }
    }
}

struct ReplyDraft: Identifiable, Equatable {
    let id: UUID
    let text: String
    let vibe: Vibe
    let relationship: Relationship
    let createdAt: Date
}

struct ReplyRequest {
    let vibe: Vibe
    let relationship: Relationship
    let context: String
    let transcript: String
}

struct ReplyResponse {
    let drafts: [ReplyDraft]
}

struct TokenPack: Identifiable {
    let id: String
    let name: String
    let amount: Int
    let priceDisplay: String
}

@Model
final class TokenLedgerEntry {
    var id: UUID
    var amount: Int
    var reason: String
    var date: Date

    init(id: UUID = UUID(), amount: Int, reason: String, date: Date = .now) {
        self.id = id
        self.amount = amount
        self.reason = reason
        self.date = date
    }
}

@Model
final class ConversationHistory {
    var id: UUID
    var vibeRaw: String
    var relationshipRaw: String
    var context: String
    var transcript: String
    var reply: String
    var date: Date

    init(id: UUID = UUID(),
         vibe: Vibe,
         relationship: Relationship,
         context: String,
         transcript: String,
         reply: String,
         date: Date = .now) {
        self.id = id
        self.vibeRaw = vibe.rawValue
        self.relationshipRaw = relationship.rawValue
        self.context = context
        self.transcript = transcript
        self.reply = reply
        self.date = date
    }

    var vibe: Vibe { Vibe(rawValue: vibeRaw) ?? .flirty }
    var relationship: Relationship { Relationship(rawValue: relationshipRaw) ?? .friend }
}
