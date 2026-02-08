import Foundation
import SwiftUI
import SwiftData
import UIKit

@MainActor
final class RizzCoachState: ObservableObject {
    enum Tab: String, CaseIterable {
        case generate, history, tips
    }

    @Published var selectedVibe: Vibe = .flirty
    @Published var relationship: Relationship = .crush
    @Published var extraContext: String = ""
    @Published var transcript: String = ""
    @Published var replies: [ReplyDraft] = []
    @Published var selectedTab: Tab = .generate
    @Published var tokenBalance: Int = 25
    @Published var isGenerating = false
    @Published var toastMessage: String?
    @Published var showTokenShop = false
    @Published var copiedReplyID: UUID?

    // Persistence
    var modelContext: ModelContext?
    var historyMemory: [ConversationHistory] = []

    private let replyService: ReplyService
    private let purchaseService: PurchaseService
    private let seedKey = "rizzcoach_seeded_sample_v1"
    private var seededMemory = false

    init(replyService: ReplyService? = nil,
         purchaseService: PurchaseService = StubPurchaseService(),
         modelContext: ModelContext? = nil) {
        if let service = replyService {
            self.replyService = service
        } else if let key = GrokConfig.apiKey {
            self.replyService = GrokReplyService(apiKey: key)
        } else {
            self.replyService = MockReplyService()
        }
        self.purchaseService = purchaseService
        self.modelContext = modelContext
        seedSampleHistoryIfNeeded()
    }

    var packs: [TokenPack] {
        [
            TokenPack(id: "rizz.tokens.50", name: "50 Tokens", amount: 50, priceDisplay: "$0.99"),
            TokenPack(id: "rizz.tokens.150", name: "150 Tokens", amount: 150, priceDisplay: "$2.99"),
            TokenPack(id: "rizz.tokens.500", name: "500 Tokens", amount: 500, priceDisplay: "$7.99"),
            TokenPack(id: "rizz.tokens.1500", name: "1500 Tokens", amount: 1500, priceDisplay: "$19.99")
        ]
    }

    func generate() async {
        guard !isGenerating else { return }
        guard transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            toastMessage = "Add recent messages first."
            return
        }
        guard tokenBalance >= 3 else {
            toastMessage = "Not enough tokens."
            return
        }

        isGenerating = true
        tokenBalance -= 3
        defer { isGenerating = false }

        do {
            let response = try await replyService.generateReplies(
                request: ReplyRequest(
                    vibe: selectedVibe,
                    relationship: relationship,
                    context: extraContext,
                    transcript: transcript
                )
            )
            replies = response.drafts
            saveHistoryIfNeeded(with: response.drafts.first)
        } catch {
            toastMessage = "Generation failed."
        }
    }

    func selectReply(_ reply: ReplyDraft) {
        // Placeholder for insert/share hook if wired to Messages.
        copiedReplyID = reply.id
        toastMessage = "Copied to clipboard"
        UIPasteboard.general.string = reply.text
        Task { [weak self] in
            try await Task.sleep(nanoseconds: 2_000_000_000)
            if self?.copiedReplyID == reply.id { self?.copiedReplyID = nil }
        }
    }

    func watchAd() {
        tokenBalance += 5
        logLedger(amount: 5, reason: "watch_ad")
    }

    func purchase(pack: TokenPack) async {
        do {
            let amount = try await purchaseService.purchase(pack: pack)
            tokenBalance += amount
            logLedger(amount: amount, reason: "purchase_\(pack.id)")
        } catch {
            toastMessage = "Purchase failed."
        }
    }

    func setTab(_ tab: Tab) {
        selectedTab = tab
    }

    func attachContext(_ ctx: ModelContext) {
        modelContext = ctx
        seedSampleHistoryIfNeeded()
    }

    private func saveHistoryIfNeeded(with reply: ReplyDraft?) {
        guard let reply else { return }
        let record = ConversationHistory(
            vibe: reply.vibe,
            relationship: reply.relationship,
            context: extraContext,
            transcript: transcript,
            reply: reply.text
        )

        if let ctx = modelContext {
            ctx.insert(record)
            try? ctx.save()
        } else {
            historyMemory.insert(record, at: 0)
        }
    }

    func historyItems(queryResults: [ConversationHistory]) -> [ConversationHistory] {
        if let _ = modelContext {
            return queryResults.sorted { $0.date > $1.date }
        }
        return historyMemory
    }

    private func logLedger(amount: Int, reason: String) {
        guard let ctx = modelContext else { return }
        let entry = TokenLedgerEntry(amount: amount, reason: reason)
        ctx.insert(entry)
        try? ctx.save()
    }

    private func seedSampleHistoryIfNeeded() {
        if let ctx = modelContext {
            guard !UserDefaults.standard.bool(forKey: seedKey) else { return }
            let sample = ConversationHistory(
                vibe: .chill,
                relationship: .friend,
                context: "Figuring out weekend plans; keep it light.",
                transcript: "Them: Hey! Are you free this weekend?\nYou: Let me check...",
                reply: "Sounds good to me. Want to keep it low-key and grab coffee?"
            )
            ctx.insert(sample)
            try? ctx.save()
            UserDefaults.standard.set(true, forKey: seedKey)
        } else {
            guard seededMemory == false else { return }
            seededMemory = true
            let sample = ConversationHistory(
                vibe: .chill,
                relationship: .friend,
                context: "Figuring out weekend plans; keep it light.",
                transcript: "Them: Hey! Are you free this weekend?\nYou: Let me check...",
                reply: "Sounds good to me. Want to keep it low-key and grab coffee?"
            )
            historyMemory.insert(sample, at: 0)
        }
    }
}
