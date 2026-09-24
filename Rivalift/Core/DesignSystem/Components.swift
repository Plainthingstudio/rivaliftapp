import SwiftUI

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.spacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(.white)
            .background(Theme.accent.opacity(isEnabled ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(Theme.accent)
            .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

struct StatTile: View {
    var value: String
    var label: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.statValue)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.statLabel)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Photo-less avatar: colored circle with initials (AUTH-04).
struct AvatarView: View {
    var name: String
    var size: CGFloat = 40

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap(\.first).map(String.init).joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }

    var body: some View {
        Circle()
            .fill(Theme.avatarColor(for: name))
            .frame(width: size, height: size)
            .overlay {
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

struct PRBadge: View {
    var body: some View {
        Label("PR", systemImage: "trophy.fill")
            .labelStyle(.titleAndIcon)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(.white)
            .background(Theme.pr, in: Capsule())
            .accessibilityLabel("Personal record")
    }
}

struct EmptyStateView: View {
    var systemImage: String
    var title: LocalizedStringKey
    var message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Text(title).font(.title3.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.primary)
                    .padding(.top, 8)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

/// Muscle-group icon used instead of per-exercise illustrations for the MVP (appendix A.4).
struct ExerciseIcon: View {
    var muscle: MuscleGroup
    var size: CGFloat = 40

    var symbol: String {
        switch muscle {
        case .chest: "figure.strengthtraining.traditional"
        case .back, .traps: "figure.rower"
        case .shoulders: "figure.arms.open"
        case .biceps, .triceps, .forearms: "dumbbell.fill"
        case .core: "figure.core.training"
        case .quads, .hamstrings, .glutes, .calves: "figure.strengthtraining.functional"
        case .fullBody: "figure.cross.training"
        }
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.45))
            .foregroundStyle(Theme.accent)
            .frame(width: size, height: size)
            .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}

enum DurationFormatter {
    /// "1:05:09" or "5:09".
    static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }

    /// "1h 5m" or "42m".
    static func short(_ seconds: Int) -> String {
        let m = max(0, seconds) / 60
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
    }
}
