import SwiftUI
import UIKit

struct ContextInputView: View {
    @Binding var extraContext: String
    @Binding var transcript: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            labeledField(title: "EXTRA CONTEXT") {
                TextField("They love hiking, dogs, etc...", text: $extraContext, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(RZColor.surface)
                    .overlay(Rectangle().stroke(RZColor.border, lineWidth: 1))
            }

            RecentMessagesBuilder(transcript: $transcript)
        }
    }

    private func labeledField<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            content()
        }
    }
}
private enum Role: String, CaseIterable, Identifiable {
    case you = "You"
    case them = "Them"
    var id: String { rawValue }
}

private struct Message: Identifiable, Equatable {
    let id = UUID()
    var role: Role
    var text: String
}

struct RecentMessagesBuilder: View {
    @Binding var transcript: String

    @State private var messages: [Message] = []
    @State private var draftText: String = ""
    @State private var draftRole: Role = .them
    @FocusState private var focusedComposer: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECENT MESSAGES")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if messages.isEmpty {
                Text("No messages yet. Add one below or paste from clipboard.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RZColor.surfaceAlt)
                    .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    ForEach(messages) { msg in
                        HStack(alignment: .top, spacing: 8) {
                            Text(msg.role == .you ? "🫵" : "💬")
                            VStack(alignment: .leading, spacing: 4) {
                                Text(msg.role.rawValue)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(msg.text)
                                    .font(.body)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                messages.removeAll { $0.id == msg.id }
                                syncTranscript()
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(RZColor.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(RZColor.border, lineWidth: 1)
                        )
                        .cornerRadius(8)
                    }
                }
            }

            HStack(spacing: 8) {
                Picker("Role", selection: $draftRole) {
                    ForEach(Role.allCases) { role in
                        Text(role.rawValue).tag(role)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)

                TextField("Type a message…", text: $draftText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedComposer)

                Button {
                    addDraft()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            HStack {
                Button {
                    if let s = UIPasteboard.general.string {
                        pasteAndParse(s)
                    }
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }

                Button {
                    messages.removeAll()
                    syncTranscript()
                } label: {
                    Label("Clear", systemImage: "trash")
                }

                Spacer()
                Text("\(messages.count) messages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .onAppear(perform: loadFromTranscriptIfNeeded)
    }

    private func addDraft() {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(.init(role: draftRole, text: trimmed))
        draftText = ""
        focusedComposer = true
        syncTranscript()
    }

    private func syncTranscript() {
        transcript = messages
            .map { "\($0.role.rawValue): \($0.text)" }
            .joined(separator: "\n")
    }

    private func loadFromTranscriptIfNeeded() {
        guard messages.isEmpty, transcript.isEmpty == false else { return }
        pasteAndParse(transcript)
    }

    private func pasteAndParse(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        var parsed: [Message] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if trimmed.lowercased().hasPrefix("you:") {
                parsed.append(.init(role: .you, text: String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)))
            } else if trimmed.lowercased().hasPrefix("them:") {
                parsed.append(.init(role: .them, text: String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)))
            } else {
                parsed.append(.init(role: .them, text: trimmed))
            }
        }
        messages = parsed
        syncTranscript()
    }
}

