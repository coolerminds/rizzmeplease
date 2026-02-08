import SwiftUI

struct TokenShopView: View {
    let packs: [TokenPack]
    let onPurchase: (TokenPack) -> Void
    let onWatchAd: () -> Void
    let tokenBalance: Int

    var body: some View {
        NavigationStack {
            List {
                Section("Current Balance") {
                    HStack {
                        Image(systemName: "moonphase.first.quarter")
                        Text("\(tokenBalance) tokens")
                            .font(.headline)
                    }
                }

                Section("Token Packs") {
                    ForEach(packs) { pack in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(pack.name).font(.headline)
                                Text(pack.priceDisplay).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Buy") { onPurchase(pack) }
                                .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Earn") {
                    Button {
                        onWatchAd()
                    } label: {
                        HStack {
                            Image(systemName: "play.rectangle")
                            Text("Watch Ad (+5 tokens)")
                        }
                    }
                }
            }
            .navigationTitle("Token Shop")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
