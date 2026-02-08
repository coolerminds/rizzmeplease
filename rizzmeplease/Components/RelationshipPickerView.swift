import SwiftUI

struct RelationshipPickerView: View {
    let selected: Relationship
    let onSelect: (Relationship) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHO ARE THEY?")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(Relationship.allCases) { relationship in
                    let isSelected = relationship == selected
                    Button {
                        onSelect(relationship)
                    } label: {
                        VStack(spacing: 6) {
                            Text(relationship.emoji)
                            Text(relationship.title)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .background(RZColor.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? RZColor.teal : RZColor.border, lineWidth: isSelected ? 2 : 1)
                        )
                        .scaleEffect(isSelected ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.12), value: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
