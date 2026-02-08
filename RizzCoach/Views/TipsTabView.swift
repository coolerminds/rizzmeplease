import SwiftUI

struct TipsTabView: View {
    private struct TipCard: Identifiable {
        let id = UUID()
        let color: Color
        let title: String
        let detail: String
        let icon: String
    }

    private let tips: [TipCard] = [
        .init(color: Color(hex: "#F9CA24"), title: "Add Context", detail: "The more info you give, the better the replies!", icon: "lightbulb"),
        .init(color: Color(hex: "#4ECDC4"), title: "Match the Vibe", detail: "Choose a vibe that fits your relationship with them.", icon: "sparkles"),
        .init(color: Color(hex: "#FF6B9D"), title: "Be Authentic", detail: "Edit the replies to sound like you!", icon: "target")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(tips) { tip in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: tip.icon)
                                .font(.headline)
                            Text(tip.title)
                                .font(.headline.weight(.semibold))
                        }
                        Text(tip.detail)
                            .font(.subheadline)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(tip.color.opacity(0.9))
                    .foregroundStyle(.black)
                    .cornerRadius(8)
                }
            }
            .padding(16)
        }
        .background(RZColor.surface)
    }
}
