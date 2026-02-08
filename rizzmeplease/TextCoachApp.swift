import SwiftUI
import SwiftData

@main
struct TextCoachApp: App {
    @StateObject private var state = RizzCoachState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .modelContainerIfAvailable()
        }
    }
}

private extension View {
    @ViewBuilder
    func modelContainerIfAvailable() -> some View {
        if #available(iOS 17.0, *) {
            self.modelContainer(for: [TokenLedgerEntry.self, ConversationHistory.self])
        } else {
            self
        }
    }
}
