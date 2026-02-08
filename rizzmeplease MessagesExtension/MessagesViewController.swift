//
//  MessagesViewController.swift
//  rizzmeplease MessagesExtension
//
//  In-thread suggestion scaffold for Messages extension.
//

import UIKit
import Messages
import SwiftUI

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
        viewModel.presentationStyle = presentationStyle
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        viewModel.presentationStyle = presentationStyle
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
        viewModel.registerInsertedSuggestion(id: suggestion.id)
        insertDraft(suggestion.text)
    }

    private func insertDraft(_ draft: String) {
        guard let conversation = activeConversation else {
            viewModel.errorMessage = "No active conversation found."
            return
        }

        conversation.insertText(draft) { [weak self] error in
            Task { @MainActor in
                if let error {
                    self?.viewModel.errorMessage = "Insert failed: \(error.localizedDescription)"
                } else {
                    self?.viewModel.lastInsertedDraft = draft
                }
            }
        }
    }
}

// MARK: - View Model

@MainActor
private final class ThreadSuggestionViewModel: ObservableObject {
    private static let mockModeKey = "messages_extension_mock_mode_enabled"

    @Published var goal: ExtensionGoal = .getReply
    @Published var tone: ExtensionTone = .friendly
    @Published var relationshipType: ExtensionRelationshipType = .friend
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

    private let apiService = ThreadSuggestionService()

    var canGenerate: Bool {
        parsedMessages().count >= 2 && !isLoading && !isSubmittingFeedback
    }

    var canSubmitFeedback: Bool {
        selectedSuggestionId != nil && selectedSuggestionSetId != nil && !isSubmittingFeedback
    }

    func refreshConversation(_ conversation: MSConversation, style: MSMessagesAppPresentationStyle) {
        presentationStyle = style
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
        switch relationshipType {
        case .friend:
            transcriptInput = """
            Them: You still down for dinner tonight?
            You: Yeah, maybe 20 minutes late.
            Them: No stress. Want me to order for you?
            """
            extraContext = "I want to sound considerate without overexplaining."
        case .stranger:
            transcriptInput = """
            Them: Hey, we met at the event yesterday.
            You: Hey, good to hear from you.
            Them: Want to grab coffee sometime?
            """
            extraContext = "Keep things friendly and safe."
        case .professional:
            transcriptInput = """
            Them: Can you send the revised deck today?
            You: I can send an updated version this afternoon.
            Them: Great, what time should I expect it?
            """
            extraContext = "Clear and professional tone."
        case .dating:
            transcriptInput = """
            Them: Last night was fun.
            You: Agreed, I had a good time too.
            Them: Want to do something this weekend?
            """
            extraContext = "Confident but warm."
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
        } catch {
            feedbackStatusMessage = "Feedback failed: \(error.localizedDescription)"
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
            return
        }

        isLoading = true
        defer { isLoading = false }

        let request = ExtensionSuggestionRequest(
            conversation: .init(messages: messages),
            goal: goal.rawValue,
            tone: tone.rawValue,
            relationshipType: relationshipType.rawValue,
            context: normalizedExtraContext,
            threadContext: threadContextFromSelection()
        )

        do {
            let result = try await apiService.generateSuggestions(request: request)
            suggestions = result.suggestions.sorted { $0.rank < $1.rank }
            selectedSuggestionSetId = result.suggestionSetId
            usedFallback = false
        } catch {
            let fallback = mockSuggestionResult(modePrefix: "fallback")
            suggestions = fallback.suggestions
            selectedSuggestionSetId = fallback.suggestionSetId
            usedFallback = true
            errorMessage = "Live API unavailable. Showing local drafts."
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
        let key = "\(goal.rawValue)_\(relationshipType.rawValue)_\(tone.rawValue)"
        let suggestionSetId = "\(modePrefix)_set_\(key)"
        let base = mockSuggestionText()

        let suggestions = base.enumerated().map { index, text in
            ExtensionSuggestion(
                id: "\(modePrefix)_\(key)_\(index + 1)",
                rank: index + 1,
                text: text,
                rationale: "\(tone.title) \(modePrefix) suggestion for \(relationshipType.title.lowercased()) context.",
                confidenceScore: nil
            )
        }

        return ExtensionSuggestionsResult(
            suggestionSetId: suggestionSetId,
            suggestions: suggestions
        )
    }

    private func mockSuggestionText() -> [String] {
        switch (goal, relationshipType) {
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.presentationStyle == .compact {
                        Button("Open Full Composer") {
                            onExpand()
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Text("iMessage only shares limited thread context. Paste recent lines for better quality.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle(
                        "Local Mock Mode",
                        isOn: Binding(
                            get: { viewModel.isMockModeEnabled },
                            set: { viewModel.setMockMode($0) }
                        )
                    )

                    Button("Load Sample Transcript") {
                        viewModel.loadMockTranscript()
                    }
                    .buttonStyle(.bordered)

                    Picker("Goal", selection: $viewModel.goal) {
                        ForEach(ExtensionGoal.allCases) { goal in
                            Text(goal.title).tag(goal)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Tone", selection: $viewModel.tone) {
                        ForEach(ExtensionTone.allCases) { tone in
                            Text(tone.title).tag(tone)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Relationship", selection: $viewModel.relationshipType) {
                        ForEach(ExtensionRelationshipType.allCases) { relationship in
                            Text(relationship.title).tag(relationship)
                        }
                    }
                    .pickerStyle(.menu)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Extra Context")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Anything important to include?", text: $viewModel.extraContext)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Transcript (Them:/You:)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $viewModel.transcriptInput)
                            .frame(minHeight: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }

                    if !viewModel.selectedMessageSummary.isEmpty {
                        Text("Selected thread context: \(viewModel.selectedMessageSummary)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        Task {
                            await viewModel.generateSuggestions()
                        }
                    } label: {
                        if viewModel.isLoading && !viewModel.isMockModeEnabled {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Generate Drafts")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canGenerate)

                    if viewModel.usedFallback {
                        Text("Using local fallback suggestions.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if let inserted = viewModel.lastInsertedDraft {
                        Text("Inserted draft: \(inserted)")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    ForEach(viewModel.suggestions) { suggestion in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(suggestion.text)
                                .font(.body)
                            Text(suggestion.rationale)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Insert Draft") {
                                onInsertDraft(suggestion)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if viewModel.selectedSuggestionId != nil {
                        Divider()
                        Text("Suggestion Feedback")
                            .font(.headline)

                        Picker("Outcome", selection: $viewModel.selectedOutcome) {
                            ForEach(ExtensionFeedbackOutcome.allCases) { outcome in
                                Text(outcome.title).tag(outcome)
                            }
                        }
                        .pickerStyle(.menu)

                        TextField("Optional feedback notes", text: $viewModel.feedbackNotes)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            Task {
                                await viewModel.submitFeedback()
                            }
                        } label: {
                            if viewModel.isSubmittingFeedback {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Submit Feedback")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.canSubmitFeedback)
                    }

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
                                Text(
                                    "\(event.outcome.title): \(event.suggestionId) at \(event.createdAt.formatted(date: .omitted, time: .shortened))"
                                )
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(12)
            }
            .navigationTitle("Text Coach")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - API Models

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
