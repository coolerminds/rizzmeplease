import SwiftUI

// Design tokens and palette for the flat “vine” aesthetic.
enum RZColor {
    static let teal = Color(hex: "#00BF8F")
    static let flirty = Color(hex: "#FF6B9D")
    static let smooth = Color(hex: "#4ECDC4")
    static let bold = Color(hex: "#FF6F61")
    static let classy = Color(hex: "#9B59B6")
    static let funny = Color(hex: "#F9CA24")
    static let chill = Color(hex: "#74B9FF")
    static let surface = Color(.systemBackground)
    static let surfaceAlt = Color(.systemGray6)
    static let border = Color.black.opacity(0.08)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")))
        var rgb: UInt64 = 0
        _ = scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
