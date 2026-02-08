import SwiftUI

public struct AppLogoView: View {
    private let showWordmark: Bool
    private let size: CGFloat
    private let spacing: CGFloat

    public init(showWordmark: Bool = true, size: CGFloat = 28, spacing: CGFloat = 8) {
        self.showWordmark = showWordmark
        self.size = size
        self.spacing = spacing
    }

    public var body: some View {
        HStack(spacing: spacing) {
            ZStack {
                Circle()
                    .fill(RZColor.teal)
                    .frame(width: size, height: size)
                Image(systemName: "wand.and.stars")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.6, height: size * 0.6)
                    .foregroundStyle(.white)
            }
            if showWordmark {
                Text("RizzCoach")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
            }
        }
    }
}

#Preview("Logo + Wordmark") {
    AppLogoView()
        .padding()
}

#Preview("Mark Only") {
    AppLogoView(showWordmark: false)
        .padding()
}
