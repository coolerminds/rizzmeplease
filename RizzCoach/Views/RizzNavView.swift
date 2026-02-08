import SwiftUI

struct RizzNavView: View {
    let selected: RizzCoachState.Tab
    let onSelect: (RizzCoachState.Tab) -> Void

    var body: some View {
        HStack(spacing: 10) {
            navButton(tab: .generate, icon: "sparkles", label: "Generate")
            navButton(tab: .history, icon: "ellipsis.bubble", label: "History")
            navButton(tab: .tips, icon: "lightbulb", label: "Tips")
        }
    }

    private func navButton(tab: RizzCoachState.Tab, icon: String, label: String) -> some View {
        let isSelected = tab == selected
        return Button {
            onSelect(tab)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(label)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? RZColor.teal : RZColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(RZColor.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
