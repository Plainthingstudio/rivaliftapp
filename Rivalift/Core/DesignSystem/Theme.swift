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

    /// Flame and trophy red from the Home redesign (Figma "Home Update").
    static let heat = Color(red: 194 / 255, green: 29 / 255, blue: 58 / 255)

    /// Blue primary gradient (Figma "Button/Primary"), also used for trained days.
    static var primaryGradient: LinearGradient {
        LinearGradient(stops: [
            .init(color: Color(red: 64 / 255, green: 87 / 255, blue: 235 / 255), location: 0.025),
            .init(color: Color(red: 26 / 255, green: 32 / 255, blue: 80 / 255), location: 0.79),
            .init(color: Color(red: 20 / 255, green: 26 / 255, blue: 69 / 255), location: 1),
        ], startPoint: .top, endPoint: .bottom)
    }

    /// Black card lit by soft inner rim shadows (dark glass cards on Home).
    static var glassFill: some ShapeStyle {
        Color.black
            .shadow(.inner(color: Color(white: 0.16).opacity(0.5), radius: 24, y: 12))
            .shadow(.inner(color: Color(white: 0.22).opacity(0.2), radius: 34.5, y: 28))
            .shadow(.inner(color: Color(red: 21 / 255, green: 0, blue: 158 / 255).opacity(0.12), radius: 27.5, x: 2, y: 4))
            .shadow(.inner(color: .white.opacity(0.1), radius: 4.5, x: 2, y: 4))
            .shadow(.inner(color: .white.opacity(0.2), radius: 7, y: 2))
    }

    /// Translucent fill for secondary buttons, chips and inputs on dark glass screens.
    static var glassControl: some ShapeStyle {
        Color.white.opacity(0.08)
            .shadow(.inner(color: .white.opacity(0.1), radius: 4.5, x: 2, y: 4))
            .shadow(.inner(color: .white.opacity(0.2), radius: 7, y: 2))
    }

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
