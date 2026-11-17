import SwiftUI

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: Theme.cornerRadius)
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }

    /// Dark glass card; callers set their own padding.
    func glassCard(cornerRadius: CGFloat = 32) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background(Theme.glassFill, in: shape).clipShape(shape)
    }
}

/// Black screen background with the blurred blue-to-red glow from the Home design ("blur top").
struct ScreenBackground: View {
    var body: some View {
        Theme.background
            .overlay(alignment: .topLeading) {
                GlowShape()
                    .fill(LinearGradient(
                        colors: [Color(red: 0x22 / 255, green: 0x2C / 255, blue: 0x71 / 255), Color(red: 0xD2 / 255, green: 0x3F / 255, blue: 0x46 / 255)],
                        startPoint: UnitPoint(x: 488.367 / 976.734, y: 530.242 / 720.97),
                        endPoint: UnitPoint(x: 562.521 / 976.734, y: 394.879 / 720.97)
                    ))
                    .opacity(0.5)
                    .frame(width: 976.734, height: 720.97)
                    .blur(radius: 75)
                    .offset(x: -279.5, y: -342)
                    .allowsHitTesting(false)
            }
            .overlay {
                // "red shine": a soft red light in the middle of every screen.
                GeometryReader { geo in
                    Circle()
                        .fill(Color(red: 0xAC / 255, green: 0x2A / 255, blue: 0x2F / 255).opacity(0.5))
                        .frame(width: 215, height: 215)
                        .blur(radius: 100)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.62)
                }
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

    /// Path copied from the Figma SVG export (976.734 × 720.97 viewBox).
    private struct GlowShape: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: .init(x: 295.005, y: 478.828))
            p.addCurve(to: .init(x: 177.263, y: 570.97), control1: .init(x: 276.472, y: 502.656), control2: .init(x: 213.873, y: 554.396))
            p.addLine(to: .init(x: 150, y: 150))
            p.addLine(to: .init(x: 826.734, y: 150))
            p.addLine(to: .init(x: 826.734, y: 478.828))
            p.addLine(to: .init(x: 734.778, y: 537.203))
            p.addCurve(to: .init(x: 654.518, y: 455.361), control1: .init(x: 717.373, y: 529.38), control2: .init(x: 677.047, y: 455.361))
            p.addCurve(to: .init(x: 621.665, y: 413.137), control1: .init(x: 626.358, y: 455.361), control2: .init(x: 637.505, y: 413.137))
            p.addCurve(to: .init(x: 551.851, y: 393.761), control1: .init(x: 605.825, y: 413.137), control2: .init(x: 588.225, y: 380.267))
            p.addCurve(to: .init(x: 512.755, y: 431.898), control1: .init(x: 515.477, y: 407.254), control2: .init(x: 525.458, y: 431.898))
            p.addCurve(to: .init(x: 483.613, y: 386.318), control1: .init(x: 500.052, y: 431.898), control2: .init(x: 500.799, y: 382.582))
            p.addCurve(to: .init(x: 450.736, y: 467.018), control1: .init(x: 466.427, y: 390.054), control2: .init(x: 460.45, y: 461.787))
            p.addCurve(to: .init(x: 395.203, y: 413.137), control1: .init(x: 441.022, y: 472.248), control2: .init(x: 424.988, y: 430.788))
            p.addCurve(to: .init(x: 295.005, y: 478.828), control1: .init(x: 339.531, y: 380.146), control2: .init(x: 318.172, y: 449.042))
            p.closeSubpath()
            return p
        }
    }
}

extension View {
    /// Glow background for a screen. Lists and forms drop their own background so it shows through.
    func screenBackground() -> some View {
        scrollContentBackground(.hidden).background { ScreenBackground() }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(.white)
            .background(Theme.primaryGradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(.white)
            .background(Theme.glassControl, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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

/// Round member avatar. Uses dummy photos until profile photos exist (AUTH-04).
struct AvatarView: View {
    var name: String
    var size: CGFloat = 40

    var body: some View {
        Image(Theme.avatarPhoto(for: name))
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
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

/// ⓘ next to "1RM" that explains the term in a popover.
struct OneRepMaxInfoButton: View {
    var unit: WeightUnit
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "info.circle")
                .font(.subheadline)
                .foregroundStyle(Theme.accent)
                .frame(minWidth: Theme.minTap, minHeight: Theme.minTap)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("What is 1RM?")
        .popover(isPresented: $isPresented) {
            OneRepMaxExplainer(unit: unit)
                .presentationCompactAdaptation(.popover)
        }
    }
}

/// Plain-language meaning of the estimated one-rep max, with an example in the user's unit.
struct OneRepMaxExplainer: View {
    var unit: WeightUnit

    var body: some View {
        let weight: Double = unit == .kg ? 60 : 135
        let reps = 8
        let weightKg = UnitConverter.toKg(weight, from: unit)
        let estimate = OneRepMax.epley(weightKg: weightKg, reps: reps)
        VStack(alignment: .leading, spacing: 10) {
            Text("1RM = one-rep max").font(.headline)
            Text("The heaviest weight you could lift for a single rep with good form.")
            Text("Rivalift estimates it from your normal sets, so you never have to test a true max. That lets you compare a set of 5 with a set of 10 on one scale.")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("weight × (1 + reps ÷ 30)").font(.subheadline.monospaced())
                Text("\(WeightFormatter.string(kg: weightKg, unit: unit, includeUnit: true)) × \(reps) reps ≈ \(WeightFormatter.string(kg: estimate, unit: unit, includeUnit: true))")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text("Only working sets of 1–12 reps count. Above 12 reps the estimate gets unreliable.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .fixedSize(horizontal: false, vertical: true)
        .padding()
        .frame(idealWidth: 320)
    }
}

// MARK: - Glass kit (Figma "Screens", dark designs)

extension Theme {
    /// Red-to-black card with a red inner glow (Figma "MetricsCard", "Week Card", "Estimate").
    static var redFill: some ShapeStyle {
        LinearGradient(stops: [
            .init(color: Theme.heat.opacity(0.8), location: 0.127),
            .init(color: .black.opacity(0.8), location: 0.251),
        ], startPoint: .top, endPoint: .bottom)
        .shadow(.inner(color: Color(red: 229 / 255, green: 0, blue: 0).opacity(0.54), radius: 21.7, y: 10.9))
        .shadow(.inner(color: Color(red: 230 / 255, green: 127 / 255, blue: 127 / 255).opacity(0.45), radius: 31.2, y: 25.3))
        .shadow(.inner(color: Color(red: 249 / 255, green: 76 / 255, blue: 76 / 255).opacity(0.34), radius: 27, y: 100))
        .shadow(.inner(color: .white.opacity(0.05), radius: 24.9, x: 1.8, y: 3.6))
        .shadow(.inner(color: .white.opacity(0.25), radius: 2.3, y: 0.9))
        .shadow(.inner(color: .white.opacity(0.26), radius: 7.2, x: 1.8, y: 3.6))
    }

    /// Bar fill for weekly charts: dark red at the top to bright red at the bottom.
    static var barGradient: LinearGradient {
        LinearGradient(stops: [
            .init(color: Color(red: 117 / 255, green: 15 / 255, blue: 0), location: 0.0125),
            .init(color: Theme.heat, location: 0.883),
        ], startPoint: .top, endPoint: .bottom)
    }
}

extension View {
    /// Red gradient card; callers set their own padding.
    func redCard(cornerRadius: CGFloat = 42) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background(Theme.redFill, in: shape)
            .clipShape(shape)
            .shadow(color: .black.opacity(0.25), radius: 15.8, y: 14.5)
    }

    /// Blurred blue light in the lower right of a glass card (rendered from the Figma blob).
    /// Apply before `glassCard()` so it sits between the black fill and the content.
    func blueGlow() -> some View {
        background {
            Image("BlueGlow")
                .resizable()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// Faint dot texture from the design, placed relative to the card and clipped by it.
    /// Drawn in a Canvas so the offset image never enlarges the card's frame or tap target.
    func dotTexture(_ name: String = "DotGrid", opacity: Double = 1, alignment: Alignment = .top, x: CGFloat = 0, y: CGFloat) -> some View {
        overlay {
            Canvas { context, size in
                let image = context.resolve(Image(name))
                let anchorY: CGFloat = alignment.vertical == .top ? image.size.height / 2 : size.height / 2
                context.opacity = opacity
                context.draw(image, at: CGPoint(x: size.width / 2 + x, y: anchorY + y))
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

/// Icon in a dashed red ring (Profile menu, league steps, settings rows).
struct RingIcon: View {
    let image: String
    var iconSize: CGFloat = 18
    /// Stronger ring and fill (leagues intro, settings, start choices).
    var strong = false

    var body: some View {
        Image(image)
            .resizable()
            .scaledToFit()
            .frame(width: iconSize, height: iconSize)
            .frame(width: 42, height: 42)
            .background(Circle().fill(Theme.heat.opacity(strong ? 0.2 : 0.1).shadow(.inner(color: .white.opacity(0.1), radius: 12.5))))
            .overlay(Circle().strokeBorder(Theme.heat.opacity(strong ? 1 : 0.5), style: StrokeStyle(lineWidth: 2, dash: [4, 3])))
            .accessibilityHidden(true)
    }
}

/// Photo for an exercise: every built-in exercise has its own (`Exercise_<key>`); custom
/// exercises get one that shows the same muscle group.
enum ExerciseArt {
    static func imageName(key: String?, muscle: MuscleGroup?) -> String {
        if let key, UIImage(named: "Exercise_\(key)") != nil { return "Exercise_\(key)" }
        let fallback: String = switch muscle {
        case .chest, .triceps, nil: "barbell_bench_press"
        case .back: "pull_up"
        case .shoulders: "arnold_press"
        case .traps, .fullBody: "deadlift"
        case .biceps, .forearms: "barbell_curl"
        case .core: "ab_wheel_rollout"
        case .quads: "barbell_back_squat"
        case .hamstrings: "romanian_deadlift"
        case .glutes: "barbell_hip_thrust"
        case .calves: "standing_calf_raise"
        }
        return "Exercise_\(fallback)"
    }
}

struct ExercisePhoto: View {
    let exercise: Exercise?
    var width: CGFloat = 96
    var height: CGFloat = 71

    var body: some View {
        Image(ExerciseArt.imageName(key: exercise?.key, muscle: exercise?.primaryMuscle))
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: height * 0.17, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Values over labels with thin dividers between them (Figma "Summary Workout", "Lifetime Stats").
struct StatStrip: View {
    let items: [(value: String, label: LocalizedStringKey)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Spacer(minLength: 6)
                    Rectangle().fill(.white.opacity(0.2)).frame(width: 0.5, height: 40)
                    Spacer(minLength: 6)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.value)
                        .font(.body.weight(.medium))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(item.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Large screen title with a small subtitle (Figma "Greeting").
struct ScreenTitle: View {
    let title: LocalizedStringKey
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.largeTitle)
            if let subtitle {
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Two or more choices in a glass capsule; the selected one sits on the blue gradient
/// (Figma "Toolbar" List/Calendar, "My templates/Programs", "Summary/History").
struct PillPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, label: LocalizedStringKey)]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let selected = option.value == selection
                Button {
                    withAnimation(.snappy) { selection = option.value }
                } label: {
                    Text(option.label)
                        .font(.subheadline.weight(selected ? .medium : .regular))
                        .foregroundStyle(selected ? Color.white : Color.white.opacity(0.7))
                        .padding(.horizontal, 20)
                        .frame(minHeight: 36)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(Theme.primaryGradient)
                                    .overlay(Capsule().strokeBorder(.white.opacity(0.1)))
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(
            Color.black
                .shadow(.inner(color: .white.opacity(0.1), radius: 4.5, x: 2, y: 4))
                .shadow(.inner(color: .white.opacity(0.2), radius: 7, y: 2)),
            in: Capsule()
        )
    }
}

/// Small capsule with an icon and short text, e.g. "18 sets", "Rest 2:30".
struct InfoChip: View {
    let icon: String
    let text: String
    var fill: Color = .white.opacity(0.12)

    var body: some View {
        HStack(spacing: 4) {
            Image(icon).accessibilityHidden(true)
            Text(text).font(.caption.weight(.light)).lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(fill, in: Capsule())
    }
}

/// Short facts separated by thin vertical lines ("Quads | Barbell").
struct DividedText: View {
    let parts: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                if index > 0 { Rectangle().fill(.white.opacity(0.3)).frame(width: 1, height: 12) }
                Text(part)
            }
        }
        .font(.caption.weight(.light))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

/// M T W T F S S toggles for training days (ISO weekdays, 1 = Monday), used in onboarding
/// and Settings for workout reminders (NOT-02).
struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    private let days: [(iso: Int, label: String)] = [(1, "M"), (2, "T"), (3, "W"), (4, "T"), (5, "F"), (6, "S"), (7, "S")]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.iso) { day in
                let isOn = selection.contains(day.iso)
                Button {
                    if isOn { selection.remove(day.iso) } else { selection.insert(day.iso) }
                } label: {
                    Text(day.label)
                        .font(.callout)
                        .frame(maxWidth: .infinity, minHeight: 37)
                        .foregroundStyle(isOn ? Color.white : Color.white.opacity(0.6))
                        .background {
                            if isOn {
                                Capsule().fill(Theme.primaryGradient)
                            } else {
                                Capsule().fill(Color.black.opacity(0.24).shadow(.inner(color: .white.opacity(0.25), radius: 1)))
                            }
                        }
                        .frame(minHeight: Theme.minTap)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Calendar(identifier: .iso8601).weekdaySymbols[day.iso % 7])
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.black.shadow(.inner(color: .white.opacity(0.2), radius: 7, y: 2)), in: Capsule())
    }
}
