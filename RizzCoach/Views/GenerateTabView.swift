import SwiftUI
import SwiftData

struct GenerateTabView: View {
    @EnvironmentObject private var state: RizzCoachState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VibeCardsView(selected: state.selectedVibe) { vibe in
                    state.selectedVibe = vibe
                }

                RelationshipPickerView(selected: state.relationship) { rel in
                    state.relationship = rel
                }

                ContextInputView(extraContext: $state.extraContext, transcript: $state.transcript)

                ReplyCardsView(
                    replies: state.replies,
                    copiedReplyID: state.copiedReplyID,
                    onSelect: state.selectReply
                )

                GenerateButtonView(
                    isLoading: state.isGenerating,
                    isEnabled: state.tokenBalance >= 3 && !state.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    tokenCost: 3
                ) {
                    Task { await state.generate() }
                }
            }
            .padding(16)
        }
        .background(RZColor.surface)
    }
}
