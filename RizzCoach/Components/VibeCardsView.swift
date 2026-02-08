import SwiftUI

struct VibeCardsView: View {
    let selected: Vibe
    let onSelect: (Vibe) -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CHOOSE YOUR VIBE")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Vibe.allCases) { vibe in
                    let isSelected = vibe == selected
                    Button {
                        onSelect(vibe)
                    } label: {
                        HStack {
                            Text(vibe.emoji)
                            Text(vibe.title)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 12)
                        .background(vibe.color)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.black.opacity(0.35) : Color.clear, lineWidth: 2)
                        )
                        .cornerRadius(8)
                        .scaleEffect(isSelected ? 1.02 : 1.0)
                        .animation(.easeInOut(duration: 0.12), value: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
