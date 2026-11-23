import SwiftUI

/// Colors and spacing. System colors keep light/dark mode and WCAG AA contrast.
enum Theme {
    /// The asset color itself, so it stays orange where a different `.tint` is set (tab bar).
    static let accent = Color("AccentColor")
    static let background = Color(.systemGroupedBackground)
    static let card = Color.white.opacity(0.06)
    static let elevated = Color.white.opacity(0.08)
    static let completedRow = Color.green.opacity(0.18)
    static let pr = Color.orange
    static let gold = Color(red: 0.95, green: 0.72, blue: 0.15)
    static let silver = Color(red: 0.66, green: 0.69, blue: 0.73)
    static let bronze = Color(red: 0.78, green: 0.50, blue: 0.28)

    /// Flame red for the streak icon.
    static let heat = Color(red: 194 / 255, green: 29 / 255, blue: 58 / 255)

    /// Blue primary gradient (Figma "Home" progress bars and icon circles), also used for trained days.
    static var primaryGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 0, green: 0x72 / 255, blue: 0xBE / 255), Color(red: 0x27 / 255, green: 0xA9 / 255, blue: 1)], startPoint: .top, endPoint: .bottom)
    }

    /// Card fill (Figma "bg-card-primary") and thin border ("border-primary").
    static let glassFill = Color.white.opacity(0.1)
    static let border = Color.white.opacity(0.16)
    static let success = Color(red: 0x17 / 255, green: 0xB2 / 255, blue: 0x6A / 255)

    /// Fill for secondary buttons, chips and inputs (Figma "Start Training" button).
    static let glassControl = Color(white: 0x29 / 255)

    /// Fade behind floating bottom buttons so scrolled content dims under them.
    static var bottomFade: LinearGradient {
        LinearGradient(colors: [.black.opacity(0), .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
    }

    /// Row fill for lists and forms: a light frost over the black glow background.
    static let listRow = Color.white.opacity(0.07)

    static let cornerRadius: CGFloat = 24
    static let spacing: CGFloat = 16
    /// Minimum tap target (section 11).
    static let minTap: CGFloat = 44

    /// Dummy photos until profile photos exist (AUTH-04).
    static let avatarPhotos = ["Avatar1", "Avatar2", "Avatar3"]

    /// The same name always gets the same photo.
    static func avatarPhoto(for name: String) -> String {
        let hash = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7fffffff }
        return avatarPhotos[hash % avatarPhotos.count]
    }
}

extension Font {
    static let statValue = Font.system(.title2, design: .rounded).weight(.bold)
    static let statLabel = Font.caption.weight(.medium)
    static let heroNumber = Font.system(.largeTitle, design: .rounded).weight(.heavy)
}
