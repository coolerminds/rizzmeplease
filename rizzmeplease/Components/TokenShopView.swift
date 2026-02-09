import SwiftUI

struct TokenShopView: View {
    let packs: [TokenPack]
    let onPurchase: (TokenPack) -> Void
    let onWatchAd: () -> Void
    let tokenBalance: Int
    #if DEBUG
    @State private var apiBaseURLDraft = ""
    @State private var apiConfigStatus: String?
    #endif

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

                #if DEBUG
                Section("Debug API URL") {
                    TextField("http://192.168.x.x:8000/api/v1", text: $apiBaseURLDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.URL)

                    Button("Apply Local URL") {
                        let trimmed = apiBaseURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else {
                            AppRuntimeConfig.setDebugAPIBaseURLOverride(nil)
                            apiConfigStatus = "Cleared override."
                            return
                        }

                        guard URL(string: trimmed) != nil else {
                            apiConfigStatus = "Invalid URL format."
                            return
                        }

                        AppRuntimeConfig.setDebugAPIBaseURLOverride(trimmed)
                        apiConfigStatus = "Applied override."
                    }

                    Button("Use Production URL") {
                        AppRuntimeConfig.setDebugAPIBaseURLOverride(nil)
                        apiBaseURLDraft = ""
                        apiConfigStatus = "Using production API URL."
                    }
                    .foregroundStyle(.secondary)

                    Text("Current: \(AppRuntimeConfig.apiBaseURLString)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let apiConfigStatus {
                        Text(apiConfigStatus)
                            .font(.footnote)
                    }
                }
                #endif
            }
            .navigationTitle("Token Shop")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            #if DEBUG
            apiBaseURLDraft = AppRuntimeConfig.debugAPIBaseURLOverride ?? ""
            #endif
        }
    }
}
