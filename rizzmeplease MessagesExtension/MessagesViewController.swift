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
    @Published var uiMood: UIMood = .friendly
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
        case .friend, .family:
            transcriptInput = """
            Them: You still down for dinner tonight?
            You: Yeah, maybe 20 minutes late.
            Them: No stress. Want me to order for you?
            """
            extraContext = "I want to sound considerate without overexplaining."
        case .colleague, .boss:
            transcriptInput = """
            Them: Can you send the revised deck today?
            You: I can send an updated version this afternoon.
            Them: Great, what time should I expect it?
            """
            extraContext = "Clear and professional tone."
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

    private var goalBinding: Binding<ExtensionGoal> {
        Binding(
            get: { viewModel.goal },
            set: { viewModel.dispatch(.updateGoal($0)) }
        )
    }

    private var moodBinding: Binding<UIMood> {
        Binding(
            get: { viewModel.uiMood },
            set: { viewModel.dispatch(.updateMood($0)) }
        )
    }

    private var relationshipBinding: Binding<UIRelationship> {
        Binding(
            get: { viewModel.uiRelationship },
            set: { viewModel.dispatch(.updateRelationship($0)) }
        )
    }

    private var mockModeBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isMockModeEnabled },
            set: { viewModel.dispatch(.toggleMockMode($0)) }
        )
    }

    private var outcomeBinding: Binding<ExtensionFeedbackOutcome> {
        Binding(
            get: { viewModel.selectedOutcome },
            set: { viewModel.dispatch(.updateOutcome($0)) }
        )
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { viewModel.feedbackNotes },
            set: { viewModel.dispatch(.updateFeedbackNotes($0)) }
        )
    }

    private var extraContextBinding: Binding<String> {
        Binding(
            get: { viewModel.extraContext },
            set: { viewModel.dispatch(.updateExtraContext($0)) }
        )
    }

    private var transcriptBinding: Binding<String> {
        Binding(
            get: { viewModel.transcriptInput },
            set: { viewModel.dispatch(.updateTranscript($0)) }
        )
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    headerLayer

                    if viewModel.isCoachExpanded {
                        VStack(alignment: .leading, spacing: 12) {
                            workflowLayer
                            modeLayer
                            goalLayer
                            moodLayer
                            relationshipLayer
                            composerLayer
                            suggestionsLayer

                            if viewModel.selectedSuggestionId != nil {
                                feedbackLayer
                                    .transition(
                                        .asymmetric(
                                            insertion: .move(edge: .bottom).combined(with: .opacity),
                                            removal: .opacity
                                        )
                                    )
                            }

                            #if DEBUG
                            if !viewModel.recentEvents.isEmpty {
                                eventLayer
                            }
                            #endif
                        }
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            )
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.85), value: viewModel.isCoachExpanded)
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: viewModel.workflowStage)
    }

    private func setCoachExpanded(_ expanded: Bool) {
        viewModel.dispatch(.toggleCoachExpanded(expanded))
        if expanded && viewModel.presentationStyle == .compact {
            onExpand()
        }
    }

    private var headerLayer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Text Coach")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                    Text("iMessage only shares limited thread context. Paste recent lines for better quality.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 6)

                Button {
                    setCoachExpanded(!viewModel.isCoachExpanded)
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.isCoachExpanded ? "Collapse" : "Expand")
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: viewModel.isCoachExpanded ? "chevron.down" : "chevron.up")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(Color(red: 0.00, green: 0.48, blue: 1.00))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.00, green: 0.48, blue: 1.00).opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.isCoachExpanded ? "Collapse text coach panel" : "Expand text coach panel")
                .accessibilityHint("Shows or hides the advanced drafting controls")
            }

            if let status = statusMessage {
                Text(status.text)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(status.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(status.color.opacity(0.12))
                    .clipShape(Capsule(style: .continuous))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var statusMessage: (text: String, color: Color)? {
        if let error = viewModel.errorMessage, !error.isEmpty {
            return (error, .red)
        }
        if viewModel.usedFallback {
            return ("Live API unavailable. Showing local fallback drafts.", .orange)
        }
        if let feedback = viewModel.feedbackStatusMessage, !feedback.isEmpty {
            return (feedback, .secondary)
        }
        return nil
    }

    private var workflowLayer: some View {
        DynamicLayerCard(
            title: "Workflow",
            subtitle: viewModel.workflowHint
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ThreadWorkflowStage.allCases, id: \.self) { stage in
                        let isCurrent = stage == viewModel.workflowStage
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isCurrent ? Color(red: 0.00, green: 0.48, blue: 1.00) : Color.secondary.opacity(0.25))
                                .frame(width: 8, height: 8)
                            Text(stage.title)
                                .font(.caption.weight(isCurrent ? .semibold : .regular))
                        }
                        .foregroundStyle(isCurrent ? Color(red: 0.00, green: 0.48, blue: 1.00) : Color.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(
                                    isCurrent
                                    ? Color(red: 0.00, green: 0.48, blue: 1.00).opacity(0.14)
                                    : Color.secondary.opacity(0.10)
                                )
                        )
                    }
                }
            }

            if let inserted = viewModel.lastInsertedDraft {
                Text("Inserted draft: \(inserted)")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .lineLimit(2)
            }
        }
    }

    private var modeLayer: some View {
        DynamicLayerCard(
            title: "Mode",
            subtitle: "Switch between local and live behavior"
        ) {
            Toggle(isOn: mockModeBinding) {
                Text("Local Mock Mode")
                    .font(.subheadline)
            }
            .tint(Color(red: 0.20, green: 0.78, blue: 0.35))
            .accessibilityLabel("Local mock mode")

            Button("Load Sample Transcript ◇") {
                viewModel.dispatch(.loadSampleTranscript)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color(red: 0.00, green: 0.48, blue: 1.00))
            .buttonStyle(.plain)
            .frame(minHeight: 44, alignment: .leading)
            .accessibilityLabel("Load sample transcript")

            if !viewModel.selectedMessageSummary.isEmpty {
                Text("Selected context: \(viewModel.selectedMessageSummary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var goalLayer: some View {
        DynamicLayerCard(
            title: "Goal",
            subtitle: "Pick your drafting objective"
        ) {
            HStack(spacing: 8) {
                ForEach(ExtensionGoal.allCases) { goal in
                    SelectionChip(
                        title: goal.title,
                        subtitle: nil,
                        emoji: nil,
                        isSelected: goalBinding.wrappedValue == goal,
                        minHeight: 44
                    ) {
                        goalBinding.wrappedValue = goal
                    }
                }
            }
        }
    }

    private var moodLayer: some View {
        DynamicLayerCard(
            title: "Mood",
            subtitle: "Guide style and energy"
        ) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(UIMood.allCases) { mood in
                    SelectionChip(
                        title: mood.title,
                        subtitle: nil,
                        emoji: mood.emoji,
                        isSelected: moodBinding.wrappedValue == mood,
                        minHeight: 50
                    ) {
                        moodBinding.wrappedValue = mood
                    }
                    .accessibilityLabel("\(mood.title) mood")
                }
            }
        }
    }

    private var relationshipLayer: some View {
        DynamicLayerCard(
            title: "Relationship",
            subtitle: "Tune language to the person"
        ) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(UIRelationship.allCases) { relationship in
                    SelectionChip(
                        title: relationship.title,
                        subtitle: nil,
                        emoji: relationship.emoji,
                        isSelected: relationshipBinding.wrappedValue == relationship,
                        minHeight: 50
                    ) {
                        relationshipBinding.wrappedValue = relationship
                    }
                    .accessibilityLabel("\(relationship.title) relationship")
                }
            }
        }
    }

    private var composerLayer: some View {
        DynamicLayerCard(
            title: "Composer",
            subtitle: "Context and transcript"
        ) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Extra Context")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Anything important to include?", text: extraContextBinding)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Color(.systemGray6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Transcript (Them:/You:)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Them:")
                        .font(.subheadline.weight(.medium))
                    Text("You:")
                        .font(.subheadline.weight(.medium))

                    TextEditor(text: transcriptBinding)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                }
            }

            Button {
                viewModel.dispatch(.generateTapped)
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 46)
                } else {
                    Text("Generate Drafts")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(viewModel.canGenerate ? Color(red: 0.00, green: 0.48, blue: 1.00) : Color(.systemGray3))
            )
            .buttonStyle(.plain)
            .disabled(!viewModel.canGenerate)
            .accessibilityLabel("Generate drafts")
        }
    }

    private var suggestionsLayer: some View {
        DynamicLayerCard(
            title: "Suggestions",
            subtitle: "Tap insert to place draft into compose box"
        ) {
            if viewModel.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Generating drafts...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.suggestions.isEmpty {
                Text("No drafts yet. Generate to populate suggestions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.suggestions) { suggestion in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("#\(suggestion.rank)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(red: 0.00, green: 0.48, blue: 1.00))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(red: 0.00, green: 0.48, blue: 1.00).opacity(0.12))
                                .clipShape(Capsule(style: .continuous))
                            Spacer(minLength: 4)
                            if let confidence = suggestion.confidenceScore {
                                Text("\(Int(confidence * 100))%")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(suggestion.text)
                            .font(.body)

                        Text(suggestion.rationale)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("Insert Draft") {
                            onInsertDraft(suggestion)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.00, green: 0.48, blue: 1.00))
                        .buttonStyle(.plain)
                        .frame(minHeight: 44, alignment: .leading)
                        .accessibilityLabel("Insert draft number \(suggestion.rank)")
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    private var feedbackLayer: some View {
        DynamicLayerCard(
            title: "Feedback",
            subtitle: "Tell us how the inserted draft performed"
        ) {
            Picker("Outcome", selection: outcomeBinding) {
                ForEach(ExtensionFeedbackOutcome.allCases) { outcome in
                    Text(outcome.title).tag(outcome)
                }
            }
            .pickerStyle(.segmented)

            TextField("Optional feedback notes", text: notesBinding)
                .textFieldStyle(.roundedBorder)

            Button {
                viewModel.dispatch(.submitFeedbackTapped)
            } label: {
                if viewModel.isSubmittingFeedback {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                } else {
                    Text("Submit Feedback")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(viewModel.canSubmitFeedback ? Color(red: 0.00, green: 0.48, blue: 1.00) : Color(.systemGray3))
            )
            .buttonStyle(.plain)
            .disabled(!viewModel.canSubmitFeedback)
            .accessibilityLabel("Submit feedback")

            if let feedbackMessage = viewModel.feedbackStatusMessage {
                Text(feedbackMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if viewModel.isMockModeEnabled && !viewModel.mockFeedbackEvents.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Mock Feedback Log")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(Array(viewModel.mockFeedbackEvents.prefix(3))) { event in
                        Text("\(event.outcome.title): \(event.suggestionId) at \(event.createdAt.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var eventLayer: some View {
        DynamicLayerCard(
            title: "Event Stream",
            subtitle: "Recent UI events"
        ) {
            ForEach(viewModel.recentEvents.prefix(6), id: \.self) { event in
                Text(event)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct DynamicLayerCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content
        }
        .padding(13)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
}

private struct SelectionChip: View {
    let title: String
    let subtitle: String?
    let emoji: String?
    let isSelected: Bool
    let minHeight: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: subtitle == nil ? 0 : 2) {
                HStack(spacing: 4) {
                    if let emoji {
                        Text(emoji)
                    }
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(
                isSelected
                ? Color(red: 0.00, green: 0.48, blue: 1.00)
                : .primary
            )
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        isSelected
                        ? Color(red: 0.00, green: 0.48, blue: 1.00).opacity(0.14)
                        : Color(.systemGray6)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(
                        isSelected
                        ? Color(red: 0.00, green: 0.48, blue: 1.00).opacity(0.45)
                        : Color.black.opacity(0.06),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

// MARK: - API Models

private enum UIMood: String, CaseIterable, Identifiable {
    case friendly
    case professional
    case casual
    case excited
    case empathetic
    case formal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .friendly: return "Friendly"
        case .professional: return "Professional"
        case .casual: return "Casual"
        case .excited: return "Excited"
        case .empathetic: return "Empathetic"
        case .formal: return "Formal"
        }
    }

    var emoji: String {
        switch self {
        case .friendly: return "😊"
        case .professional: return "💼"
        case .casual: return "😎"
        case .excited: return "🎉"
        case .empathetic: return "💙"
        case .formal: return "🤝"
        }
    }

    var backendTone: ExtensionTone {
        switch self {
        case .friendly: return .friendly
        case .professional: return .direct
        case .casual: return .friendly
        case .excited: return .confident
        case .empathetic: return .warm
        case .formal: return .direct
        }
    }
}

private enum UIRelationship: String, CaseIterable, Identifiable {
    case friend
    case colleague
    case family
    case boss

    var id: String { rawValue }

    var title: String {
        switch self {
        case .friend: return "Friend"
        case .colleague: return "Colleague"
        case .family: return "Family"
        case .boss: return "Boss"
        }
    }

    var emoji: String {
        switch self {
        case .friend: return "👥"
        case .colleague: return "💼"
        case .family: return "👨‍👩‍👧"
        case .boss: return "👔"
        }
    }

    var backendRelationship: ExtensionRelationshipType {
        switch self {
        case .friend: return .friend
        case .colleague: return .professional
        case .family: return .friend
        case .boss: return .professional
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
        #if DEBUG
        return "http://127.0.0.1:8000/api/v1"
        #else
        return "https://api.textcoach.app/api/v1"
        #endif
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
