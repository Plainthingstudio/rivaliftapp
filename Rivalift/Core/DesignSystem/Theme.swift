import SwiftUI

/// Colors and spacing. System colors keep light/dark mode and WCAG AA contrast.
enum Theme {
    static let accent = Color.accentColor
    static let background = Color(.systemGroupedBackground)
    static let card = Color(.secondarySystemGroupedBackground)
    static let elevated = Color(.tertiarySystemGroupedBackground)
    static let completedRow = Color.green.opacity(0.18)
    static let pr = Color.orange
    static let gold = Color(red: 0.95, green: 0.72, blue: 0.15)
    static let silver = Color(red: 0.66, green: 0.69, blue: 0.73)
    static let bronze = Color(red: 0.78, green: 0.50, blue: 0.28)

    static let cornerRadius: CGFloat = 16
    static let spacing: CGFloat = 16
    /// Minimum tap target (section 11).
    static let minTap: CGFloat = 44

    static let avatarPalette: [Color] = [.orange, .pink, .purple, .blue, .teal, .green, .indigo, .red]

    static func avatarColor(for name: String) -> Color {
        let hash = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7fffffff }
        return avatarPalette[hash % avatarPalette.count]
    }
}

extension Font {
    static let statValue = Font.system(.title2, design: .rounded).weight(.bold)
    static let statLabel = Font.caption.weight(.medium)
    static let heroNumber = Font.system(.largeTitle, design: .rounded).weight(.heavy)
}
