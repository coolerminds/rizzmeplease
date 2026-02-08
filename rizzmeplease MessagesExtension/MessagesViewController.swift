//
//  MessagesViewController.swift
//  rizzmeplease MessagesExtension
//
//  In-thread suggestion scaffold for Messages extension.
//

import UIKit
import Messages
import SwiftUI
import Combine

class MessagesViewController: MSMessagesAppViewController {
    private let viewModel = ThreadSuggestionViewModel()
    private var hostingController: UIHostingController<ThreadSuggestionRootView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        installRootView()
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        viewModel.refreshConversation(conversation, style: presentationStyle)
    }

    override func didResignActive(with conversation: MSConversation) {
        super.didResignActive(with: conversation)
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.willTransition(to: presentationStyle)
        viewModel.dispatch(.updatePresentationStyle(presentationStyle))
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        viewModel.dispatch(.updatePresentationStyle(presentationStyle))
    }

    private func installRootView() {
        let rootView = ThreadSuggestionRootView(
            viewModel: viewModel,
            onInsertDraft: { [weak self] suggestion in
                self?.insertSuggestion(suggestion)
            },
            onExpand: { [weak self] in
                self?.requestPresentationStyle(.expanded)
            }
        )

        let host = UIHostingController(rootView: rootView)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
        hostingController = host
    }

    private func insertSuggestion(_ suggestion: ExtensionSuggestion) {
        viewModel.dispatch(.suggestionInserted(suggestion))
        insertDraft(suggestion.text)
    }

    private func insertDraft(_ draft: String) {
        guard let conversation = activeConversation else {
            viewModel.errorMessage = "No active conversation found."
            return
        }

        conversation.insertText(draft) { [weak self] error in
            guard let self else { return }
            Task { @MainActor in
                self.applyInsertResult(draft: draft, error: error)
            }
        }
    }

    @MainActor
    private func applyInsertResult(draft: String, error: Error?) {
        if let error {
            viewModel.errorMessage = "Insert failed: \(error.localizedDescription)"
        } else {
            viewModel.lastInsertedDraft = draft
        }
    }
}

// MARK: - View Model

private enum ThreadWorkflowStage: String, CaseIterable {
    case configure
    case generating
    case reviewing
    case inserted
    case submittingFeedback
    case complete

    var title: String {
        switch self {
        case .configure: return "Configure"
        case .generating: return "Generating"
        case .reviewing: return "Review"
        case .inserted: return "Inserted"
        case .submittingFeedback: return "Submitting Feedback"
        case .complete: return "Complete"
        }
    }
}

private enum ThreadSuggestionEvent {
    case toggleCoachExpanded(Bool)
    case toggleMockMode(Bool)
    case loadSampleTranscript
    case updateGoal(ExtensionGoal)
    case updateMood(UIMood)
    case updateRelationship(UIRelationship)
    case updateExtraContext(String)
    case updateTranscript(String)
    case generateTapped
    case suggestionInserted(ExtensionSuggestion)
    case updateOutcome(ExtensionFeedbackOutcome)
    case updateFeedbackNotes(String)
    case submitFeedbackTapped
    case clearTransientMessages
    case updatePresentationStyle(MSMessagesAppPresentationStyle)
}

@MainActor
private final class ThreadSuggestionViewModel: ObservableObject {
    private static let mockModeKey = "messages_extension_mock_mode_enabled"

    @Published var workflowStage: ThreadWorkflowStage = .configure
    @Published var isCoachExpanded = false
    @Published var goal: ExtensionGoal = .getReply
    @Published var uiMood: UIMood = .smooth
    @Published var uiRelationship: UIRelationship = .friend
    @Published var extraContext = ""
    @Published var transcriptInput = ""
    @Published var suggestions: [ExtensionSuggestion] = []
    @Published var isLoading = false
    @Published var isSubmittingFeedback = false
    @Published var isMockModeEnabled = UserDefaults.standard.bool(forKey: mockModeKey)
    @Published var usedFallback = false
    @Published var errorMessage: String?
    @Published var lastInsertedDraft: String?
    @Published var feedbackStatusMessage: String?
    @Published var selectedSuggestionId: String?
    @Published var selectedSuggestionSetId: String?
    @Published var selectedOutcome: ExtensionFeedbackOutcome = .worked
    @Published var feedbackNotes = ""
    @Published var mockFeedbackEvents: [MockFeedbackEvent] = []
    @Published var selectedMessageSummary = ""
    @Published var presentationStyle: MSMessagesAppPresentationStyle = .compact
    @Published var recentEvents: [String] = []

    private let apiService = ThreadSuggestionService()

    var canGenerate: Bool {
        parsedMessages().count >= 2 && !isLoading && !isSubmittingFeedback
    }

    var canSubmitFeedback: Bool {
        selectedSuggestionId != nil && selectedSuggestionSetId != nil && !isSubmittingFeedback
    }

    var workflowHint: String {
        switch workflowStage {
        case .configure:
            return "Set intent and context, then generate drafts."
        case .generating:
            return "Building suggestions from your thread context."
        case .reviewing:
            return "Pick the best draft and insert it into Messages."
        case .inserted:
            return "Draft inserted. You can now log outcome feedback."
        case .submittingFeedback:
            return "Saving feedback."
        case .complete:
            return "Feedback saved. Generate again when ready."
        }
    }

    func dispatch(_ event: ThreadSuggestionEvent) {
        switch event {
        case .toggleCoachExpanded(let expanded):
            isCoachExpanded = expanded
            workflowStage = expanded ? workflowStage : .configure
            recordEvent(expanded ? "coach_expanded" : "coach_collapsed")

        case .toggleMockMode(let enabled):
            setMockMode(enabled)
            workflowStage = .configure
            recordEvent(enabled ? "mock_mode_enabled" : "mock_mode_disabled")

        case .loadSampleTranscript:
            loadMockTranscript()
            workflowStage = .configure
            recordEvent("sample_loaded")

        case .updateGoal(let goal):
            self.goal = goal
            workflowStage = .configure
            recordEvent("goal_\(goal.rawValue)")

        case .updateMood(let mood):
            uiMood = mood
            workflowStage = .configure
            recordEvent("mood_\(mood.rawValue)")

        case .updateRelationship(let relationship):
            uiRelationship = relationship
            workflowStage = .configure
            recordEvent("relationship_\(relationship.rawValue)")

        case .updateExtraContext(let context):
            extraContext = context

        case .updateTranscript(let transcript):
            transcriptInput = transcript

        case .generateTapped:
            workflowStage = .generating
            clearTransientMessages()
            recordEvent("generate_tapped")
            Task { [weak self] in
                await self?.generateSuggestions()
            }

        case .suggestionInserted(let suggestion):
            registerInsertedSuggestion(id: suggestion.id)
            workflowStage = .inserted
            recordEvent("inserted_\(suggestion.id)")

        case .updateOutcome(let outcome):
            selectedOutcome = outcome
            workflowStage = .inserted

        case .updateFeedbackNotes(let notes):
            feedbackNotes = notes

        case .submitFeedbackTapped:
            guard canSubmitFeedback else {
                feedbackStatusMessage = "Insert one suggestion before submitting feedback."
                return
            }
            workflowStage = .submittingFeedback
            recordEvent("submit_feedback_tapped")
            Task { [weak self] in
                await self?.submitFeedback()
            }

        case .clearTransientMessages:
            clearTransientMessages()

        case .updatePresentationStyle(let style):
            presentationStyle = style
        }
    }

    func refreshConversation(_ conversation: MSConversation, style: MSMessagesAppPresentationStyle) {
        dispatch(.updatePresentationStyle(style))
        selectedMessageSummary = Self.extractSelectedMessageSummary(from: conversation)

        if transcriptInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if selectedMessageSummary.isEmpty {
                transcriptInput = "Them: \nYou: "
            } else {
                transcriptInput = "Them: \(selectedMessageSummary)\nYou: "
            }
        }
    }

    func setMockMode(_ enabled: Bool) {
        isMockModeEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.mockModeKey)
        feedbackStatusMessage = enabled
            ? "Mock mode enabled. Suggestions and feedback are local."
            : "Mock mode disabled. Using API."
    }

    func loadMockTranscript() {
        switch uiRelationship {
        case .friend:
            transcriptInput = """
            Them: You still down for dinner tonight?
            You: Yeah, maybe 20 minutes late.
            Them: No stress. Want me to order for you?
            """
            extraContext = "I want to sound considerate without overexplaining."
        case .work:
            transcriptInput = """
            Them: Can you send the revised deck today?
            You: I can send an updated version this afternoon.
            Them: Great, what time should I expect it?
            """
            extraContext = "Clear and professional tone."
        case .crush, .dating:
            transcriptInput = """
            Them: Hey! Are you free this weekend?
            You: Let me check...
            Them: We should do something fun.
            """
            extraContext = "Keep it playful, confident, and not too long."
        }
    }

    func registerInsertedSuggestion(id: String) {
        selectedSuggestionId = id
        feedbackStatusMessage = "Draft inserted. Add outcome feedback when ready."
    }

    func submitFeedback() async {
        errorMessage = nil
        feedbackStatusMessage = nil

        guard let suggestionSetId = selectedSuggestionSetId,
              let suggestionId = selectedSuggestionId else {
            feedbackStatusMessage = "Insert one suggestion before submitting feedback."
            return
        }

        let notes = normalizedFeedbackNotes

        if isMockModeEnabled {
            mockFeedbackEvents.insert(
                MockFeedbackEvent(
                    id: "mock_feedback_\(mockFeedbackEvents.count + 1)",
                    suggestionId: suggestionId,
                    outcome: selectedOutcome,
                    notes: notes,
                    createdAt: Date()
                ),
                at: 0
            )
            feedbackStatusMessage = "Saved feedback locally (mock mode)."
            feedbackNotes = ""
            workflowStage = .complete
            return
        }

        isSubmittingFeedback = true
        defer { isSubmittingFeedback = false }

        let request = ExtensionFeedbackRequest(
            suggestionSetId: suggestionSetId,
            suggestionId: suggestionId,
            outcome: selectedOutcome.rawValue,
            followUpText: nil,
            notes: notes
        )

        do {
            _ = try await apiService.submitFeedback(request: request)
            feedbackStatusMessage = "Feedback submitted successfully."
            feedbackNotes = ""
            workflowStage = .complete
        } catch {
            feedbackStatusMessage = "Feedback failed: \(error.localizedDescription)"
            workflowStage = .inserted
        }
    }

    func generateSuggestions() async {
        errorMessage = nil
        lastInsertedDraft = nil
        feedbackStatusMessage = nil
        selectedSuggestionId = nil
        selectedSuggestionSetId = nil

        let messages = parsedMessages()
        guard messages.count >= 2 else {
            errorMessage = "Add at least two lines in transcript (e.g. Them:, You:)."
            return
        }

        if isMockModeEnabled {
            let mockResult = mockSuggestionResult(modePrefix: "mock")
            suggestions = mockResult.suggestions
            selectedSuggestionSetId = mockResult.suggestionSetId
            usedFallback = false
            workflowStage = .reviewing
            return
        }

        isLoading = true
        defer { isLoading = false }

        let request = ExtensionSuggestionRequest(
            conversation: .init(messages: messages),
            goal: goal.rawValue,
            tone: uiMood.backendTone.rawValue,
            relationshipType: uiRelationship.backendRelationship.rawValue,
            context: normalizedExtraContext,
            threadContext: threadContextFromSelection()
        )

        do {
            let result = try await apiService.generateSuggestions(request: request)
            suggestions = result.suggestions.sorted { $0.rank < $1.rank }
            selectedSuggestionSetId = result.suggestionSetId
            usedFallback = false
            workflowStage = .reviewing
        } catch {
            let fallback = mockSuggestionResult(modePrefix: "fallback")
            suggestions = fallback.suggestions
            selectedSuggestionSetId = fallback.suggestionSetId
            usedFallback = true
            errorMessage = "Live API unavailable. Showing local drafts."
            workflowStage = .reviewing
        }
    }

    private func clearTransientMessages() {
        errorMessage = nil
        feedbackStatusMessage = nil
    }

    private func recordEvent(_ value: String) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        recentEvents.insert("\(timestamp): \(value)", at: 0)
        if recentEvents.count > 8 {
            recentEvents.removeLast(recentEvents.count - 8)
        }
    }

    private var normalizedExtraContext: String? {
        let trimmed = extraContext.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var normalizedFeedbackNotes: String? {
        let trimmed = feedbackNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func threadContextFromSelection() -> ExtensionSuggestionRequest.ConversationData? {
        guard !selectedMessageSummary.isEmpty else { return nil }
        return .init(
            messages: [
                .init(
                    sender: "them",
                    text: selectedMessageSummary,
                    timestamp: ISO8601DateFormatter().string(from: Date())
                )
            ]
        )
    }

    private func parsedMessages() -> [ExtensionSuggestionRequest.ConversationData.MessageData] {
        let iso8601 = ISO8601DateFormatter()
        let lines = transcriptInput
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return lines.prefix(30).map { line in
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
    }

    private func mockSuggestionResult(modePrefix: String) -> ExtensionSuggestionsResult {
        let key = "\(goal.rawValue)_\(uiRelationship.rawValue)_\(uiMood.rawValue)"
        let suggestionSetId = "\(modePrefix)_set_\(key)"
        let base = mockSuggestionText()

        let suggestions = base.enumerated().map { index, text in
            ExtensionSuggestion(
                id: "\(modePrefix)_\(key)_\(index + 1)",
                rank: index + 1,
                text: text,
                rationale: "\(uiMood.title) \(modePrefix) suggestion for \(uiRelationship.title.lowercased()) context.",
                confidenceScore: nil
            )
        }

        return ExtensionSuggestionsResult(
            suggestionSetId: suggestionSetId,
            suggestions: suggestions
        )
    }

    private func mockSuggestionText() -> [String] {
        switch (goal, uiRelationship.backendRelationship) {
        case (.getReply, .friend):
            return [
                "Love that. What ended up happening after?",
                "Nice, I want the full story when you get a second.",
                "That sounds fun. What was the best part?"
            ]
        case (.getReply, .stranger):
            return [
                "Good hearing from you. How has your week been?",
                "Thanks for reaching out. What are you up to today?",
                "Nice to connect. What made you message?"
            ]
        case (.getReply, .professional):
            return [
                "Thanks for the update. What is the next step from your side?",
                "Understood. Is there anything you need from me today?",
                "Appreciate the note. What timeline are we targeting?"
            ]
        case (.getReply, .dating):
            return [
                "I had a great time too. What do you feel like doing next?",
                "Same here. What would make this weekend fun for you?",
                "Glad you said that. Should we plan something low-key this week?"
            ]
        case (.askMeetup, .friend):
            return [
                "Want to grab a quick coffee later this week?",
                "We should catch up in person soon. Free Thursday?",
                "Let us do dinner this week. What day works?"
            ]
        case (.askMeetup, .stranger):
            return [
                "If you are open to it, we could meet for coffee in a public spot.",
                "Happy to continue this in person sometime this week if you are comfortable.",
                "Would you be up for a quick daytime coffee meetup?"
            ]
        case (.askMeetup, .professional):
            return [
                "Would a short call tomorrow afternoon be useful?",
                "Happy to meet for a 20-minute sync this week if that helps.",
                "Should we set a brief meeting to align on next steps?"
            ]
        case (.askMeetup, .dating):
            return [
                "I am into this. Want to grab a drink Friday evening?",
                "Let us continue this in person. Are you free this weekend?",
                "I would love to see you again. Want to plan something this week?"
            ]
        case (.setBoundary, .friend):
            return [
                "I care about you, but I need to pass this time.",
                "I am not up for that right now, thanks for understanding.",
                "I need a little space today, we can catch up soon."
            ]
        case (.setBoundary, .stranger):
            return [
                "Thanks, but I am not comfortable with that.",
                "I am going to pass. Wishing you well.",
                "I prefer to keep this conversation here for now."
            ]
        case (.setBoundary, .professional):
            return [
                "I cannot commit to that timeline right now.",
                "That is outside my current scope, so I need to decline.",
                "I can support an alternative, but not this specific request."
            ]
        case (.setBoundary, .dating):
            return [
                "I like talking with you, but I need to move slower.",
                "I am not comfortable with that, and I want to be clear.",
                "I am going to pass on that, but thanks for understanding."
            ]
        }
    }

    private static func extractSelectedMessageSummary(from conversation: MSConversation) -> String {
        guard let selectedMessage = conversation.selectedMessage else {
            return ""
        }

        let rawCandidates: [String?] = [selectedMessage.summaryText]
        for candidate in rawCandidates {
            let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        if let url = selectedMessage.url,
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for name in ["text", "body", "message", "summary"] {
                if let value = queryItems.first(where: { $0.name == name })?.value {
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        return trimmed
                    }
                }
            }
        }

        return ""
    }
}

// MARK: - UI

private struct ThreadSuggestionRootView: View {
    @ObservedObject var viewModel: ThreadSuggestionViewModel
    let onInsertDraft: (ExtensionSuggestion) -> Void
    let onExpand: () -> Void
    @State private var selectedTab: RizzSectionTab = .generate

    private var moodBinding: Binding<UIMood> {
        Binding(get: { viewModel.uiMood }, set: { viewModel.dispatch(.updateMood($0)) })
    }

    private var relationshipBinding: Binding<UIRelationship> {
        Binding(get: { viewModel.uiRelationship }, set: { viewModel.dispatch(.updateRelationship($0)) })
    }

    private var extraContextBinding: Binding<String> {
        Binding(get: { viewModel.extraContext }, set: { viewModel.dispatch(.updateExtraContext($0)) })
    }

    private var transcriptBinding: Binding<String> {
        Binding(get: { viewModel.transcriptInput }, set: { viewModel.dispatch(.updateTranscript($0)) })
    }

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    topHeader
                    tabsRow
                    bodyContent
                }
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding(.horizontal, 6)
        }
    }

    private var topHeader: some View {
        HStack {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.white)
                .font(.title3.weight(.semibold))
            Spacer()
            Text("RizzHelper")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "moonphase.first.quarter")
                    .font(.callout)
                Text("25")
                    .font(.headline.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(red: 0.00, green: 0.75, blue: 0.56))
    }

    private var tabsRow: some View {
        HStack(spacing: 8) {
            ForEach(RizzSectionTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                    if tab == .generate && viewModel.presentationStyle == .compact {
                        onExpand()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(tab.icon)
                        Text(tab.title)
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(selectedTab == tab ? .white : Color(.darkText))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selectedTab == tab ? Color(red: 0.00, green: 0.75, blue: 0.56) : .white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.black.opacity(0.14), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(.white)
    }

    @ViewBuilder
    private var bodyContent: some View {
        switch selectedTab {
        case .generate:
            generateContent
        case .history:
            placeholderCard(
                title: "History",
                body: "Generate and insert drafts to populate your in-thread history."
            )
        case .tips:
            VStack(spacing: 10) {
                tipCard(color: Color(red: 0.97, green: 0.79, blue: 0.14), icon: "💡", title: "Add Context", body: "The more info you give, the better the replies.")
                tipCard(color: Color(red: 0.30, green: 0.80, blue: 0.76), icon: "✨", title: "Match the Vibe", body: "Choose a vibe that fits your relationship.")
                tipCard(color: Color(red: 0.96, green: 0.45, blue: 0.69), icon: "🎯", title: "Be Authentic", body: "Edit drafts so they sound like you.")
            }
            .padding(14)
        }
    }

    private var generateContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("CHOOSE YOUR VIBE")
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 10) {
                ForEach(UIMood.allCases) { mood in
                    vibeTile(mood: mood, selected: mood == moodBinding.wrappedValue)
                }
            }

            sectionTitle("WHO ARE THEY?")
            HStack(spacing: 8) {
                ForEach(UIRelationship.allCases) { relationship in
                    Button {
                        relationshipBinding.wrappedValue = relationship
                    } label: {
                        VStack(spacing: 6) {
                            Text(relationship.emoji)
                                .font(.headline)
                            Text(relationship.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.black.opacity(0.75))
                        }
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(relationshipBinding.wrappedValue == relationship ? Color(red: 0.00, green: 0.75, blue: 0.56) : Color.black.opacity(0.16), lineWidth: relationshipBinding.wrappedValue == relationship ? 2 : 1)
                        )
                        .scaleEffect(relationshipBinding.wrappedValue == relationship ? 1.04 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
            }

            fieldSection(title: "EXTRA CONTEXT") {
                TextField("They love hiking, dogs, etc...", text: extraContextBinding)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(.white)
                    .overlay(Rectangle().stroke(Color.black.opacity(0.14), lineWidth: 1))
            }

            fieldSection(title: "RECENT MESSAGES") {
                TextEditor(text: transcriptBinding)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(.white)
                    .overlay(Rectangle().stroke(Color.black.opacity(0.14), lineWidth: 1))
            }

            if let error = viewModel.errorMessage, !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                viewModel.dispatch(.generateTapped)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                    Text(viewModel.isLoading ? "Generating..." : "Generate Replies")
                        .font(.title3.weight(.bold))
                }
                .foregroundStyle(Color.black.opacity(0.55))
                .frame(maxWidth: .infinity, minHeight: 66)
                .background(
                    Rectangle().fill(viewModel.canGenerate ? Color(red: 0.00, green: 0.75, blue: 0.56).opacity(0.25) : Color.gray.opacity(0.28))
                )
                .overlay(Rectangle().stroke(Color.black.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canGenerate)

            if !viewModel.suggestions.isEmpty {
                sectionTitle("SUGGESTED REPLIES")
                VStack(spacing: 10) {
                    ForEach(viewModel.suggestions) { suggestion in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(suggestion.text)
                                .font(.body)
                            Button("Insert Draft") {
                                onInsertDraft(suggestion)
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(red: 0.00, green: 0.48, blue: 1.00))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.black.opacity(0.12), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(14)
    }

    private func vibeTile(mood: UIMood, selected: Bool) -> some View {
        Button {
            moodBinding.wrappedValue = mood
        } label: {
            HStack(spacing: 8) {
                Text(mood.emoji)
                    .font(.title3)
                Text(mood.title)
                    .font(.title3.weight(.bold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 72)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(mood.fillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selected ? Color.black.opacity(0.35) : Color.clear, lineWidth: 2)
            )
            .scaleEffect(selected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.heavy))
            .foregroundStyle(Color.black.opacity(0.68))
    }

    private func fieldSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle(title)
            content()
        }
    }

    private func placeholderCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.weight(.bold))
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }

    private func tipCard(color: Color, icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(icon)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.bold))
                Text(body)
                    .font(.subheadline)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private enum RizzSectionTab: CaseIterable {
    case generate
    case history
    case tips

    var title: String {
        switch self {
        case .generate: return "Generate"
        case .history: return "History"
        case .tips: return "Tips"
        }
    }

    var icon: String {
        switch self {
        case .generate: return "✨"
        case .history: return "💬"
        case .tips: return "💡"
        }
    }
}

// MARK: - API Models

private enum UIMood: String, CaseIterable, Identifiable {
    case flirty
    case smooth
    case bold
    case classy
    case funny
    case chill

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

    var fillColor: Color {
        switch self {
        case .flirty: return Color(red: 0.95, green: 0.40, blue: 0.62)
        case .smooth: return Color(red: 0.33, green: 0.78, blue: 0.75)
        case .bold: return Color(red: 1.00, green: 0.44, blue: 0.38)
        case .classy: return Color(red: 0.62, green: 0.36, blue: 0.82)
        case .funny: return Color(red: 0.97, green: 0.80, blue: 0.10)
        case .chill: return Color(red: 0.45, green: 0.69, blue: 0.94)
        }
    }

    var backendTone: ExtensionTone {
        switch self {
        case .flirty: return .warm
        case .smooth: return .friendly
        case .bold: return .confident
        case .classy: return .direct
        case .funny: return .friendly
        case .chill: return .warm
        }
    }
}

private enum UIRelationship: String, CaseIterable, Identifiable {
    case crush
    case friend
    case work
    case dating

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

    var backendRelationship: ExtensionRelationshipType {
        switch self {
        case .crush: return .dating
        case .friend: return .friend
        case .work: return .professional
        case .dating: return .dating
        }
    }
}

private enum ExtensionGoal: String, CaseIterable, Identifiable {
    case getReply = "get_reply"
    case askMeetup = "ask_meetup"
    case setBoundary = "set_boundary"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .getReply: return "Get Reply"
        case .askMeetup: return "Ask Meetup"
        case .setBoundary: return "Set Boundary"
        }
    }
}

private enum ExtensionTone: String, CaseIterable, Identifiable {
    case friendly
    case direct
    case warm
    case confident

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

private enum ExtensionRelationshipType: String, CaseIterable, Identifiable {
    case friend
    case stranger
    case professional
    case dating

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}

private enum ExtensionFeedbackOutcome: String, CaseIterable, Identifiable {
    case worked
    case noResponse = "no_response"
    case negative
    case skipped

    var id: String { rawValue }

    var title: String {
        switch self {
        case .worked: return "Worked"
        case .noResponse: return "No Response"
        case .negative: return "Negative"
        case .skipped: return "Skipped"
        }
    }
}

private struct MockFeedbackEvent: Identifiable {
    let id: String
    let suggestionId: String
    let outcome: ExtensionFeedbackOutcome
    let notes: String?
    let createdAt: Date
}

private struct ExtensionSuggestionRequest: Encodable {
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

private struct ExtensionSuggestion: Decodable, Identifiable {
    let id: String
    let rank: Int
    let text: String
    let rationale: String
    let confidenceScore: Double?
}

private struct SuggestionResponseEnvelope: Decodable {
    let success: Bool
    let data: SuggestionResponseData
}

private struct SuggestionResponseData: Decodable {
    let suggestionSetId: String
    let suggestions: [ExtensionSuggestion]
    let conversationId: String
    let createdAt: String
}

private struct ExtensionSuggestionsResult {
    let suggestionSetId: String
    let suggestions: [ExtensionSuggestion]
}

private struct ExtensionFeedbackRequest: Encodable {
    let suggestionSetId: String
    let suggestionId: String
    let outcome: String
    let followUpText: String?
    let notes: String?
}

private struct ExtensionFeedbackResponseEnvelope: Decodable {
    let success: Bool
    let data: ExtensionFeedbackData
}

private struct ExtensionFeedbackData: Decodable {
    let feedbackId: String
    let recordedAt: String
}

private struct ExtensionAuthRequest: Encodable {
    let deviceId: String
}

private struct ExtensionAuthResponseEnvelope: Decodable {
    let success: Bool
    let data: ExtensionAuthData
}

private struct ExtensionAuthData: Decodable {
    let accessToken: String
    let tokenType: String
    let userId: String
}

private struct APIErrorEnvelope: Decodable {
    struct APIErrorDetail: Decodable {
        let code: String
        let message: String
    }

    let detail: APIErrorDetail?
    let error: APIErrorDetail?
}

private enum ThreadSuggestionServiceError: Error, LocalizedError {
    case invalidURL
    case badResponse
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL."
        case .badResponse:
            return "Invalid response from suggestion API."
        case .httpError(let code, let message):
            return "HTTP \(code): \(message)"
        }
    }
}

private actor ThreadSuggestionService {
    private let baseURLString: String = {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String {
            let trimmed = configured.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return "https://rizzmeow.com/api/v1"
    }()
    private let tokenKey = "messages_extension_access_token"
    private let tokenCreatedAtKey = "messages_extension_token_created_at"

    func generateSuggestions(request: ExtensionSuggestionRequest) async throws -> ExtensionSuggestionsResult {
        let token = try await accessToken()

        do {
            return try await performSuggestionRequest(request: request, token: token)
        } catch ThreadSuggestionServiceError.httpError(let code, _) where code == 401 {
            let refreshedToken = try await createAnonymousToken(forceRefresh: true)
            return try await performSuggestionRequest(request: request, token: refreshedToken)
        }
    }

    func submitFeedback(request: ExtensionFeedbackRequest) async throws -> ExtensionFeedbackData {
        let token = try await accessToken()

        do {
            return try await performFeedbackRequest(request: request, token: token)
        } catch ThreadSuggestionServiceError.httpError(let code, _) where code == 401 {
            let refreshedToken = try await createAnonymousToken(forceRefresh: true)
            return try await performFeedbackRequest(request: request, token: refreshedToken)
        }
    }

    private func performSuggestionRequest(
        request: ExtensionSuggestionRequest,
        token: String
    ) async throws -> ExtensionSuggestionsResult {
        guard let baseURL = URL(string: baseURLString) else {
            throw ThreadSuggestionServiceError.invalidURL
        }

        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("suggestions"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ThreadSuggestionServiceError.badResponse
        }

        if httpResponse.statusCode >= 400 {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let apiError = try? decoder.decode(APIErrorEnvelope.self, from: data)
            let message = apiError?.detail?.message ?? apiError?.error?.message ?? "Request failed"
            throw ThreadSuggestionServiceError.httpError(httpResponse.statusCode, message)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let envelope = try decoder.decode(SuggestionResponseEnvelope.self, from: data)
        return ExtensionSuggestionsResult(
            suggestionSetId: envelope.data.suggestionSetId,
            suggestions: envelope.data.suggestions
        )
    }

    private func performFeedbackRequest(
        request: ExtensionFeedbackRequest,
        token: String
    ) async throws -> ExtensionFeedbackData {
        guard let baseURL = URL(string: baseURLString) else {
            throw ThreadSuggestionServiceError.invalidURL
        }

        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("feedback"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ThreadSuggestionServiceError.badResponse
        }

        if httpResponse.statusCode >= 400 {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let apiError = try? decoder.decode(APIErrorEnvelope.self, from: data)
            let message = apiError?.detail?.message ?? apiError?.error?.message ?? "Feedback request failed"
            throw ThreadSuggestionServiceError.httpError(httpResponse.statusCode, message)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let envelope = try decoder.decode(ExtensionFeedbackResponseEnvelope.self, from: data)
        return envelope.data
    }

    private func accessToken() async throws -> String {
        let defaults = UserDefaults.standard
        if let token = defaults.string(forKey: tokenKey),
           let createdAt = defaults.object(forKey: tokenCreatedAtKey) as? Date,
           Date().timeIntervalSince(createdAt) < 24 * 60 * 60 {
            return token
        }
        return try await createAnonymousToken(forceRefresh: false)
    }

    private func createAnonymousToken(forceRefresh: Bool) async throws -> String {
        let defaults = UserDefaults.standard
        if !forceRefresh,
           let token = defaults.string(forKey: tokenKey) {
            return token
        }

        guard let baseURL = URL(string: baseURLString) else {
            throw ThreadSuggestionServiceError.invalidURL
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("auth/anonymous"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let deviceId = await MainActor.run {
            UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        }
        let body = ExtensionAuthRequest(deviceId: deviceId)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ThreadSuggestionServiceError.badResponse
        }

        if httpResponse.statusCode >= 400 {
            throw ThreadSuggestionServiceError.httpError(httpResponse.statusCode, "Auth failed")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let authResponse = try decoder.decode(ExtensionAuthResponseEnvelope.self, from: data)
        let token = authResponse.data.accessToken
        defaults.set(token, forKey: tokenKey)
        defaults.set(Date(), forKey: tokenCreatedAtKey)
        return token
    }
}
