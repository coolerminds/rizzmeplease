import SwiftUI

struct GenerateButtonView: View {
    let isLoading: Bool
    let isEnabled: Bool
    let tokenCost: Int
    let action: () -> Void

    var body: some View {
        Button(action: {
            guard isEnabled else { return }
            action()
        }) {
            HStack {
                Image(systemName: "wand.and.stars")
                Text(isLoading ? "Generating..." : "Generate Replies")
                    .font(.headline.weight(.semibold))
                Spacer()
                Text("-\(tokenCost)")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isEnabled ? .primary : .secondary)
            .padding()
            .frame(maxWidth: .infinity)
            .background(isEnabled ? RZColor.teal.opacity(0.15) : RZColor.surfaceAlt)
            .overlay(Rectangle().stroke(RZColor.border, lineWidth: 1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
