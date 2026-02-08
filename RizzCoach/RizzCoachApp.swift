import SwiftUI
import SwiftData

@main
struct RizzCoachApp: App {
    @State private var state = RizzCoachState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .modelContainerIfAvailable()
        }
    }
}

private extension View {
    /// Attaches a SwiftData modelContainer when available (iOS 17+).
    func modelContainerIfAvailable() -> some View {
        if #available(iOS 17.0, *) {
            return self
                .modelContainer(for: [TokenLedgerEntry.self, ConversationHistory.self])
        } else {
            return self
        }
    }
}
