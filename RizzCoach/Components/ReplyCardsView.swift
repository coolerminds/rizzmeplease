import SwiftUI

struct ReplyCardsView: View {
    let replies: [ReplyDraft]
    let copiedReplyID: UUID?
    let onSelect: (ReplyDraft) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if replies.isEmpty {
                EmptyState()
            } else {
                ForEach(replies) { reply in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(reply.text)
                            .font(.body)
                        HStack {
                            Button {
                                onSelect(reply)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: copiedReplyID == reply.id ? "checkmark" : "doc.on.doc")
                                    Text(copiedReplyID == reply.id ? "Copied" : "Copy")
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(RZColor.surfaceAlt)
                            .cornerRadius(6)
                            Spacer()
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)
                    }
                    .padding(12)
                    .background(RZColor.surface)
                    .overlay(Rectangle().stroke(RZColor.border, lineWidth: 1))
                    .cornerRadius(8)
                }
            }
        }
    }
}

private struct EmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No replies yet")
                .font(.headline)
            Text("Pick a vibe, add context, then generate.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(RZColor.surfaceAlt)
        .cornerRadius(8)
    }
}
