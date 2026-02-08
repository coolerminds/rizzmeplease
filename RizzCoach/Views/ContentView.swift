import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var state: RizzCoachState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            RizzHeaderView(
                tokenBalance: state.tokenBalance,
                onTapTokens: { state.showTokenShop = true }
            )
            RizzNavView(selected: state.selectedTab, onSelect: state.setTab)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            Divider()
            content
                .background(RZColor.surface)
        }
        .onAppear {
            if let ctx = try? modelContext {
                state.attachContext(ctx)
            }
        }
        .sheet(isPresented: $state.showTokenShop) {
            TokenShopView(
                packs: state.packs,
                onPurchase: { pack in Task { await state.purchase(pack: pack) } },
                onWatchAd: state.watchAd,
                tokenBalance: state.tokenBalance
            )
            .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state.selectedTab {
        case .generate:
            GenerateTabView()
        case .history:
            HistoryTabView()
        case .tips:
            TipsTabView()
        }
    }
}
