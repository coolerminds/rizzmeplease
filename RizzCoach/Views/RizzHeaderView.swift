import SwiftUI

struct RizzHeaderView: View {
    let tokenBalance: Int
    let onTapTokens: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "line.3.horizontal")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Spacer()
            Text("RizzCoach")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Spacer()
            Button(action: onTapTokens) {
                HStack(spacing: 6) {
                    Image(systemName: "moonphase.first.quarter")
                        .font(.callout)
                    Text("\(tokenBalance)")
                        .font(.callout.weight(.semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.15))
                .clipShape(Capsule())
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(RZColor.teal)
    }
}
