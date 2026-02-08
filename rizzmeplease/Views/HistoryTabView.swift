import SwiftUI
import SwiftData

struct HistoryTabView: View {
    @EnvironmentObject private var state: RizzCoachState

    @Query(sort: \ConversationHistory.date, order: .reverse)
    private var storedHistory: [ConversationHistory]

    var body: some View {
        let items = state.historyItems(queryResults: storedHistory)
        if items.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No history yet")
                    .font(.headline)
                Text("Generate a reply to save it here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding()
        } else {
            List {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(item.vibe.emoji)
                            Text(item.vibe.title)
                                .fontWeight(.semibold)
                            Text("·")
                            Text(item.relationship.title)
                        }
                        .font(.subheadline)
                        Text(item.reply)
                            .font(.body)
                        Text(item.date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            .listStyle(.plain)
        }
    }
}
