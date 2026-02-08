import SwiftUI

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

            labeledField(title: "RECENT MESSAGES") {
                TextEditor(text: $transcript)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(RZColor.surface)
                    .overlay(Rectangle().stroke(RZColor.border, lineWidth: 1))
            }
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
