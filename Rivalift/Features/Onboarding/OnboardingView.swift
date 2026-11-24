import SwiftUI

/// AUTH-04 / AUTH-05 / appendix A.1: welcome, name, goal, level, unit, weekly target and
/// days, streak commitment, then a recommended program. Each choice is saved immediately
/// so closing the app mid-onboarding keeps it. No height, weight or birth date (A.1).
struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var env

    /// Question steps show "n/6"; step 7 is the plan.
    private static let questionCount = 6
    private static let planStep = 7

    private var step: Int { env.settings.onboardingStep }

    var body: some View {
        VStack(spacing: 0) {
            if step > 0 {
                VStack(spacing: 12) {
                    HStack {
                        Button {
                            setStep(step - 1)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: Theme.minTap, height: Theme.minTap)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .accessibilityLabel("Back")
                        Spacer()
                        if step <= Self.questionCount {
                            Text("\(step)/\(Self.questionCount)").font(.callout.monospacedDigit()).foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        Color.clear.frame(width: Theme.minTap, height: Theme.minTap)
                    }
                    if step <= Self.questionCount {
                        // Figma "Progress Bar": one segment per question, done ones lit.
                        HStack(spacing: 8) {
                            ForEach(1...Self.questionCount, id: \.self) { index in
                                Capsule()
                                    .fill(index <= step
                                        ? AnyShapeStyle(LinearGradient(colors: [.white, Color(red: 90 / 255, green: 92 / 255, blue: 105 / 255)], startPoint: .topTrailing, endPoint: .bottomLeading))
                                        : AnyShapeStyle(Color.white.opacity(0.1)))
                                    .frame(height: 6)
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Step \(step) of \(Self.questionCount)")
                    }
                }
                .padding(.horizontal)
            }
            Group {
                switch step {
                case 0: welcome
                case 1: NameStep { setStep(2) }
                case 2: goalStep
                case 3: levelStep
                case 4: unitStep
                case 5: ScheduleStep { setStep(6) }
                case 6: CommitStep { setStep(Self.planStep) }
                default: PlanStep { finish() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .animation(.snappy, value: step)
        }
        .screenBackground()
    }

    /// Figma "Onboarding 0 – Welcome".
    private var welcome: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 24) {
                HeroRing(image: "Icon_ob_trophy")
                VStack(spacing: 8) {
                    Text("Rivalift").font(.largeTitle)
                    Text("Lift with your friends. Win the week.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                feature("Icon_ob_n1", "Log sets in seconds", "Previous weights and rest timer built in.")
                Rectangle().fill(Theme.border).frame(height: 0.5)
                feature("Icon_ob_n2", "See yourself get stronger", "Records and your estimated one-rep max (1RM) tracked automatically.")
                Rectangle().fill(Theme.border).frame(height: 0.5)
                feature("Icon_ob_n3", "Compete every week", "Leagues reward showing up, not just lifting heavy.")
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
            Spacer()
            Button("Get Started") { setStep(1) }
                .buttonStyle(.primary)
                .accessibilityIdentifier("onboardingGetStarted")
        }
    }

    private func feature(_ icon: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            RingIcon(image: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            StepTitle(title: "What's your main goal?", subtitle: "We'll use it to suggest a program.")
            ForEach(TrainingGoal.allCases) { goal in
                BigChoice(title: goal.title, subtitle: goal.detail, isSelected: step > 2 && env.settings.goal == goal) {
                    env.settings.goal = goal
                    setStep(3)
                }
                .accessibilityIdentifier("goal-\(goal.rawValue)")
            }
            Spacer()
        }
    }

    private var levelStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            StepTitle(title: "How experienced are you with lifting?")
            ForEach(ExperienceLevel.allCases) { level in
                BigChoice(title: level.title, subtitle: level.detail, isSelected: step > 3 && env.settings.experience == level) {
                    env.settings.experience = level
                    setStep(4)
                }
                .accessibilityIdentifier("level-\(level.rawValue)")
            }
            Spacer()
        }
    }

    private var unitStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            StepTitle(title: "Which unit do you lift in?", subtitle: "You can change this anytime in Settings.")
            ForEach(WeightUnit.allCases) { unit in
                BigChoice(title: unit == .kg ? "Kilograms (kg)" : "Pounds (lb)", isSelected: env.settings.unit == unit) {
                    env.settings.unit = unit
                    setStep(5)
                }
                .accessibilityIdentifier("unit-\(unit.rawValue)")
            }
            Spacer()
            Button("Skip") { setStep(5) }
                .buttonStyle(.secondary)
        }
    }

    private func setStep(_ value: Int) {
        env.settings.onboardingStep = max(0, min(value, Self.planStep))
        env.saveSettings()
    }

    private func finish() {
        env.settings.onboardingDone = true
        env.saveSettings()
    }
}

private struct NameStep: View {
    @Environment(AppEnvironment.self) private var env
    var next: () -> Void

    @State private var name = ""
    @FocusState private var focused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What should we call you?").font(.title)
                    Text("Friends see this name in your leagues.").font(.callout).foregroundStyle(.secondary)
                }
                TextField("Enter your full name", text: $name)
                    .font(.subheadline)
                    .textContentType(.givenName)
                    .submitLabel(.continue)
                    .focused($focused)
                    .onSubmit(save)
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.white.opacity(0.1))
                            .strokeBorder(.white.opacity(0.2))
                    )
                    .accessibilityIdentifier("nameField")
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
            Spacer()
            Button("Continue", action: save)
                .buttonStyle(.primary)
                .disabled(trimmed.isEmpty)
                .accessibilityIdentifier("nameContinue")
        }
        .onAppear {
            name = env.settings.displayName
            focused = true
        }
    }

    private func save() {
        guard !trimmed.isEmpty else { return }
        env.settings.displayName = String(trimmed.prefix(30))
        env.saveSettings()
        next()
    }
}

private struct ScheduleStep: View {
    @Environment(AppEnvironment.self) private var env
    var next: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How often do you want to train?").font(.title)
            Text("Your weekly target is used for streaks and league bonus points.").font(.callout).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach([2, 3, 4, 5], id: \.self) { target in
                    pill(target == 5 ? "5+" : "\(target)", selected: env.settings.weeklyTarget == target) {
                        env.settings.weeklyTarget = target
                        env.saveSettings()
                    }
                    .accessibilityIdentifier("target-\(target)")
                    .accessibilityLabel(target == 5 ? "5 or more sessions per week" : "\(target) sessions per week")
                }
            }
            .modifier(PillTrack())
            Text("sessions per week").font(.callout).foregroundStyle(.secondary)

            Text("Which days work best?").font(.callout.weight(.medium)).padding(.top, 20)
            Text("Optional. We'll remind you on these days.").font(.callout).foregroundStyle(.secondary)
            WeekdayPicker(selection: Binding(
                get: { env.settings.trainingWeekdays },
                set: { env.settings.trainingWeekdays = $0; env.saveSettings() }
            ))
            Spacer()
            Button("Continue", action: next)
                .buttonStyle(.primary)
                .accessibilityIdentifier("scheduleContinue")
        }
    }

    private func pill(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.callout)
                .frame(maxWidth: .infinity, minHeight: 37)
                .foregroundStyle(selected ? Color.white : Color.white.opacity(0.6))
                .background {
                    if selected {
                        Capsule().fill(Theme.primaryGradient)
                    } else {
                        Capsule().fill(Color.black.opacity(0.24).shadow(.inner(color: .white.opacity(0.25), radius: 1)))
                    }
                }
                .frame(minHeight: Theme.minTap)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct CommitStep: View {
    @Environment(AppEnvironment.self) private var env
    var next: () -> Void

    @State private var weeks = 4
    private let options: [(weeks: Int, label: LocalizedStringKey)] = [
        (2, "Good start"), (4, "Strong"), (8, "Committed"), (12, "Unstoppable"),
    ]

    var body: some View {
        VStack(spacing: 16) {
            HeroRing(image: "Icon_ob_flame")
            Text("Set your streak goal").font(.title)
            Text("Hit \(env.settings.weeklyTarget) sessions a week, week after week. Streaks make the habit stick.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            VStack(spacing: 10) {
                ForEach(options, id: \.weeks) { option in
                    Button {
                        weeks = option.weeks
                    } label: {
                        HStack {
                            Text("\(option.weeks)-week streak").font(.callout)
                            Spacer()
                            Text(option.label).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .glassCard(cornerRadius: 24)
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(weeks == option.weeks ? Color.white : .clear, lineWidth: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(weeks == option.weeks ? .isSelected : [])
                }
            }
            .padding(.top, 8)
            Spacer()
            Button("Commit to My Goal") {
                env.settings.streakGoalWeeks = weeks
                env.saveSettings()
                next()
            }
            .buttonStyle(.primary)
            .accessibilityIdentifier("commitButton")
            Button("Maybe Later", action: next)
                .buttonStyle(.secondary)
        }
        .onAppear {
            if env.settings.streakGoalWeeks > 0 { weeks = env.settings.streakGoalWeeks }
        }
    }
}

/// "Building your plan": a short checklist, then the recommended program.
private struct PlanStep: View {
    @Environment(AppEnvironment.self) private var env
    var done: () -> Void

    @State private var revealed = 0
    @State private var program: TemplateRepository.Program?

    private var checks: [String] {
        let s = env.settings
        return [
            String(localized: "Goal: \(s.goal.title)"),
            String(localized: "Level: \(s.experience.title)"),
            String(localized: "\(s.weeklyTarget) sessions a week"),
            String(localized: "Picking your program"),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let program, revealed >= checks.count {
                result(program)
            } else {
                Spacer()
                VStack(spacing: 24) {
                    HeroRing(image: "Icon_ob_trophy")
                    Text("Building your plan…").font(.title)
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(Array(checks.enumerated()), id: \.offset) { index, text in
                        HStack(spacing: 8) {
                            Image(index < revealed ? "Icon_ob_done" : "Icon_ob_pending").accessibilityHidden(true)
                            Text(text).font(.callout).foregroundStyle(index < revealed ? .primary : .secondary)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
                .padding(.top, 8)
                Spacer()
            }
        }
        .animation(.snappy, value: revealed)
        .task {
            let s = env.settings
            let name = PlanRecommender.program(goal: s.goal, level: s.experience, weeklyTarget: s.weeklyTarget)
            program = env.templates.programs().first { $0.name == name }
            s.planProgram = name
            s.planID = PlanCatalog.plan(for: s.goal).id
            s.planStartedAt = Date()
            env.saveSettings()
            for index in 1...checks.count {
                try? await Task.sleep(for: .milliseconds(450))
                revealed = index
            }
        }
    }

    private func result(_ program: TemplateRepository.Program) -> some View {
        let s = env.settings
        return VStack(alignment: .leading, spacing: 16) {
            Text(s.displayName.isEmpty ? String(localized: "Your plan is ready") : String(localized: "\(s.displayName), your plan is ready"))
                .font(.title)
            ScrollView {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            Image("Icon_sparkle").accessibilityHidden(true)
                            Text("Recommended for you").font(.subheadline)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            // Plans are named for the goal; the split is what is inside (CLAUDE.md).
                            Text(PlanCatalog.plan(for: s.goal).title).font(.title2)
                            DividedText(parts: [AppEnvironment.splitName(for: program.name), s.experience.title, String(localized: "\(s.weeklyTarget)x per week")])
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
                    ForEach(program.templates) { template in
                        TemplateRowCard(template: template)
                    }
                }
            }
            Text("It's waiting for you under Start workout. You can always pick another template or build your own.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Go to Home", action: done)
                .buttonStyle(.primary)
                .accessibilityIdentifier("onboardingFinish")
        }
    }
}

extension TrainingGoal {
    var title: String {
        switch self {
        case .strength: String(localized: "Get stronger")
        case .muscle: String(localized: "Build muscle")
        case .consistency: String(localized: "Stay consistent")
        case .fitness: String(localized: "General fitness")
        }
    }

    var detail: String {
        switch self {
        case .strength: String(localized: "Lift heavier on the big lifts")
        case .muscle: String(localized: "More size, more volume")
        case .consistency: String(localized: "Build a habit that sticks")
        case .fitness: String(localized: "Feel fit and healthy")
        }
    }
}

extension ExperienceLevel {
    var title: String {
        switch self {
        case .beginner: String(localized: "Beginner")
        case .intermediate: String(localized: "Intermediate")
        case .advanced: String(localized: "Advanced")
        }
    }

    var detail: String {
        switch self {
        case .beginner: String(localized: "New to lifting or getting back into it")
        case .intermediate: String(localized: "Train regularly and know the main lifts")
        case .advanced: String(localized: "Years of structured training")
        }
    }
}

/// Option card (Figma "Onboarding 2 – Goal / Card"): white ring and green check when picked.
struct BigChoice: View {
    var title: String
    var subtitle: String?
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.callout).foregroundStyle(.white)
                    if let subtitle {
                        Text(subtitle).font(.caption.weight(.light)).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                Spacer()
                Image(isSelected ? "Icon_ob_check" : "Icon_ob_uncheck").accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, minHeight: 64)
            .glassCard(cornerRadius: 24)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(isSelected ? Color.white : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Large question title with an optional subtitle.
private struct StepTitle: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title)
            if let subtitle { Text(subtitle).font(.callout).foregroundStyle(.secondary) }
        }
        .padding(.bottom, 16)
    }
}

/// 80 pt dashed red ring around a 36 pt glyph (welcome, streak, building plan).
private struct HeroRing: View {
    let image: String

    var body: some View {
        Image(image)
            .resizable()
            .frame(width: 36, height: 36)
            .frame(width: 80, height: 80)
            .background(Circle().fill(Theme.accent.opacity(0.2).shadow(.inner(color: .white.opacity(0.1), radius: 24))))
            .overlay(Circle().strokeBorder(Theme.accent))
            .accessibilityHidden(true)
    }
}

/// Black capsule track that holds a row of pills (Figma "Weekly target", "Training Days").
private struct PillTrack: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color.black.shadow(.inner(color: .white.opacity(0.2), radius: 7, y: 2)), in: Capsule())
    }
}
