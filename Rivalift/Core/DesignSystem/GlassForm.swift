import SwiftUI

// Form building blocks in the dark glass style (Figma "Settings"). Screens that used
// `Form`/`List` sections build on these instead, so every sub-screen looks the same.

/// Thin rule between rows inside a glass card.
struct GlassDivider: View {
    var body: some View {
        Rectangle().fill(Theme.border).frame(height: 0.5)
    }
}

/// Rows stacked in a glass card.
struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
    }
}

/// Heading, glass card and optional footnote: the section used across the app.
struct GlassSection<Content: View>: View {
    var title: LocalizedStringKey?
    var footer: Text?
    @ViewBuilder var content: Content

    init(_ title: LocalizedStringKey? = nil, footer: Text? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title { Text(title).padding(.horizontal, 4) }
            GlassCard { content }
            if let footer {
                footer.font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 4)
            }
        }
    }
}

/// Ring icon, title and a trailing control.
struct GlassRow<Trailing: View>: View {
    var icon: String?
    let title: LocalizedStringKey
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            if let icon { RingIcon(image: icon, strong: true) }
            Text(title).font(.subheadline)
            Spacer(minLength: 8)
            trailing
        }
        .frame(minHeight: Theme.minTap)
    }
}

/// "+ Add …" row inside a glass card.
struct GlassAddLabel: View {
    let title: LocalizedStringKey

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.subheadline.weight(.semibold))
                .frame(width: 28, height: 28)
                .background(Theme.accent.opacity(0.3), in: Circle())
                .overlay(Circle().strokeBorder(Theme.accent))
                .accessibilityHidden(true)
            Text(title).font(.subheadline)
            Spacer()
        }
        .foregroundStyle(.white)
        .frame(minHeight: Theme.minTap)
        .contentShape(Rectangle())
    }
}

/// Round "−" button that removes a row.
struct GlassRemoveButton: View {
    let label: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "minus.circle.fill")
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: Theme.minTap, height: Theme.minTap)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.3)
        .accessibilityLabel(label)
    }
}

/// Radio row: check ring, title and an explanation.
struct GlassChoiceRow<Title: View, Detail: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder var title: Title
    @ViewBuilder var detail: Detail

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(isSelected ? "Icon_ob_check" : "Icon_ob_uncheck")
                    .resizable()
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    title.font(.subheadline.weight(isSelected ? .semibold : .regular)).foregroundStyle(.white)
                    detail.font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Value with the up/down glyph in a boxed capsule, used as a `Menu` label.
struct PillMenuLabel: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Text(text).font(.subheadline).foregroundStyle(.white).lineLimit(1)
            Image("Icon_set_updown").accessibilityHidden(true)
        }
        .glassField()
    }
}

/// Blue filter capsule (Figma "Exercises" muscle chips).
struct FilterPill: View {
    let title: String
    let isSelected: Bool
    var systemImage: String?

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            if let systemImage { Image(systemName: systemImage).font(.caption2.weight(.bold)) }
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(isSelected ? 1 : 0.7))
        .padding(.horizontal, 14)
        .frame(minHeight: 30)
        .background {
            if isSelected {
                Capsule().fill(Theme.primaryGradient)
            } else {
                Capsule().fill(Theme.glassFill).overlay(Capsule().strokeBorder(Theme.border))
            }
        }
        .frame(minHeight: Theme.minTap)
        .contentShape(Rectangle())
    }
}

extension View {
    /// Boxed field: text fields and menu values inside glass cards.
    func glassField() -> some View {
        padding(.horizontal, 13)
            .frame(minHeight: Theme.minTap)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(0.1))
                    .strokeBorder(.white.opacity(0.2))
            )
    }

    /// Glass card behind a `List` row, for lists that keep swipe and drag editing.
    func glassListRow() -> some View {
        listRowBackground(
            Color.clear
                .glassCard(cornerRadius: 20)
                .padding(.vertical, 4)
        )
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
    }

    /// Clear `List` on the screen background, with room between glass rows.
    func glassList() -> some View {
        listStyle(.plain).screenBackground()
    }
}
