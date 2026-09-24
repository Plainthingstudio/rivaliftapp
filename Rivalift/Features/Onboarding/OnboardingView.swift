import SwiftUI

/// AUTH-05 / appendix A.1: welcome, unit, weekly target, how to start. Each choice is
/// saved immediately so closing the app mid-onboarding keeps it. A new user reaches the
/// active workout in 4 taps: Get started → unit → target → Start empty.
struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var env

    private var step: Int { env.settings.onboardingStep }

    var body: some View {
        VStack(spacing: 0) {
            if step > 0 {
                HStack {
                    Button {
                        setStep(step - 1)
                    } label: {
                        Image(systemName: "chevron.left").frame(width: Theme.minTap, height: Theme.minTap)
                    }
                    .accessibilityLabel("Back")
                    Spacer()
                    Text("\(step)/3").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                    Spacer()
                    Color.clear.frame(width: Theme.minTap, height: Theme.minTap)
                }
                .padding(.horizontal)
                ProgressView(value: Double(step), total: 3)
                    .padding(.horizontal)
            }
            Group {
                switch step {
                case 0: welcome
                case 1: unitStep
                case 2: targetStep
                default: startStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
            .animation(.snappy, value: step)
        }
        .background(Theme.background)
    }

    private var welcome: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "trophy.fill")
                .font(.system(size: 72))
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Text("Rivalift").font(.largeTitle.bold())
            Text("Lift with your friends. Win the week.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Get started") { setStep(1) }
                .buttonStyle(.primary)
                .accessibilityIdentifier("onboardingGetStarted")
        }
    }

    private var unitStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Which unit do you lift in?").font(.title.bold())
            Text("You can change this anytime in Settings.").foregroundStyle(.secondary)
            ForEach(WeightUnit.allCases) { unit in
                BigChoice(title: unit == .kg ? "Kilograms (kg)" : "Pounds (lb)", isSelected: env.settings.unit == unit) {
                    env.settings.unit = unit
                    setStep(2)
                }
                .accessibilityIdentifier("unit-\(unit.rawValue)")
            }
            Spacer()
            Button("Skip") { setStep(2) }
                .frame(maxWidth: .infinity)
        }
    }

    private var targetStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How often do you want to train?").font(.title.bold())
            Text("Your weekly target is used for streaks and league bonus points.").foregroundStyle(.secondary)
            ForEach([2, 3, 4, 5], id: \.self) { target in
                BigChoice(
                    title: target == 5 ? String(localized: "5+ sessions per week") : String(localized: "\(target) sessions per week"),
                    isSelected: env.settings.weeklyTarget == target
                ) {
                    env.settings.weeklyTarget = target
                    setStep(3)
                }
                .accessibilityIdentifier("target-\(target)")
            }
            Spacer()
        }
    }

    private var startStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How do you want to start?").font(.title.bold())
            BigChoice(title: String(localized: "Start empty"), subtitle: String(localized: "Add exercises as you go"), isSelected: false) {
                finish()
                env.workout.requestStart(.empty)
            }
            .accessibilityIdentifier("startEmpty")
            Text("Start from a program").font(.headline).padding(.top, 8)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(env.templates.programs()) { program in
                        if let first = program.templates.first {
                            BigChoice(title: program.name, subtitle: program.templates.map(\.name).joined(separator: " · "), isSelected: false) {
                                finish()
                                env.workout.requestStart(.template(first.id))
                            }
                        }
                    }
                }
            }
            Button("Skip for now") { finish() }
                .frame(maxWidth: .infinity)
        }
    }

    private func setStep(_ value: Int) {
        env.settings.onboardingStep = max(0, min(value, 3))
        env.saveSettings()
    }

    private func finish() {
        env.settings.onboardingDone = true
        env.saveSettings()
    }
}

struct BigChoice: View {
    var title: String
    var subtitle: String?
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundStyle(isSelected ? Theme.accent : Color.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .stroke(isSelected ? Theme.accent : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
