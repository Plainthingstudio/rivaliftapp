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
                HStack {
                    Button {
                        setStep(step - 1)
                    } label: {
                        Image(systemName: "chevron.left").frame(width: Theme.minTap, height: Theme.minTap)
                    }
                    .accessibilityLabel("Back")
                    Spacer()
                    if step <= Self.questionCount {
                        Text("\(step)/\(Self.questionCount)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Color.clear.frame(width: Theme.minTap, height: Theme.minTap)
                }
                .padding(.horizontal)
                if step <= Self.questionCount {
                    ProgressView(value: Double(step), total: Double(Self.questionCount))
                        .padding(.horizontal)
                }
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
            VStack(alignment: .leading, spacing: 16) {
                feature("bolt.fill", "Log sets in seconds", "Previous weights and rest timer built in.")
                feature("chart.line.uptrend.xyaxis", "See yourself get stronger", "Records and 1RM tracked automatically.")
                feature("person.3.fill", "Compete every week", "Leagues reward showing up, not just lifting heavy.")
            }
            .padding(.top, 8)
            Spacer()
            Button("Get started") { setStep(1) }
                .buttonStyle(.primary)
                .accessibilityIdentifier("onboardingGetStarted")
        }
    }

    private func feature(_ icon: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's your main goal?").font(.title.bold())
            Text("We'll use it to suggest a program.").foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 16) {
            Text("How experienced are you with lifting?").font(.title.bold())
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
        VStack(alignment: .leading, spacing: 16) {
            Text("Which unit do you lift in?").font(.title.bold())
            Text("You can change this anytime in Settings.").foregroundStyle(.secondary)
            ForEach(WeightUnit.allCases) { unit in
                BigChoice(title: unit == .kg ? "Kilograms (kg)" : "Pounds (lb)", isSelected: env.settings.unit == unit) {
                    env.settings.unit = unit
                    setStep(5)
                }
                .accessibilityIdentifier("unit-\(unit.rawValue)")
            }
            Spacer()
            Button("Skip") { setStep(5) }
                .frame(maxWidth: .infinity)
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
            Text("What should we call you?").font(.title.bold())
            Text("Friends see this name in your leagues.").foregroundStyle(.secondary)
            HStack(spacing: 12) {
                AvatarView(name: trimmed.isEmpty ? "?" : trimmed, size: 52)
                TextField("Your name", text: $name)
                    .font(.title3)
                    .textContentType(.givenName)
                    .submitLabel(.continue)
                    .focused($focused)
                    .onSubmit(save)
                    .padding()
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                    .accessibilityIdentifier("nameField")
            }
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

    private let weekdays: [(iso: Int, label: String)] = [(1, "M"), (2, "T"), (3, "W"), (4, "T"), (5, "F"), (6, "S"), (7, "S")]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How often do you want to train?").font(.title.bold())
            Text("Your weekly target is used for streaks and league bonus points.").foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach([2, 3, 4, 5], id: \.self) { target in
                    pill(target == 5 ? "5+" : "\(target)", selected: env.settings.weeklyTarget == target) {
                        env.settings.weeklyTarget = target
                        env.saveSettings()
                    }
                    .accessibilityIdentifier("target-\(target)")
                    .accessibilityLabel(target == 5 ? "5 or more sessions per week" : "\(target) sessions per week")
                }
            }
            Text("sessions per week").font(.subheadline).foregroundStyle(.secondary)

            Text("Which days work best?").font(.headline).padding(.top, 16)
            Text("Optional. We'll plan around these days.").font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(weekdays, id: \.iso) { day in
                    let isOn = env.settings.trainingWeekdays.contains(day.iso)
                    pill(day.label, selected: isOn) {
                        var days = env.settings.trainingWeekdays
                        if isOn { days.remove(day.iso) } else { days.insert(day.iso) }
                        env.settings.trainingWeekdays = days
                        env.saveSettings()
                    }
                    .accessibilityLabel(Calendar(identifier: .iso8601).weekdaySymbols[day.iso % 7])
                }
            }
            Spacer()
            Button("Continue", action: next)
                .buttonStyle(.primary)
                .accessibilityIdentifier("scheduleContinue")
        }
    }

    private func pill(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: Theme.minTap)
                .foregroundStyle(selected ? .white : .primary)
                .background(selected ? Theme.accent : Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            Image(systemName: "flame.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("Set your streak goal").font(.title.bold())
            Text("Hit \(env.settings.weeklyTarget) sessions a week, week after week. Streaks make the habit stick.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            VStack(spacing: 10) {
                ForEach(options, id: \.weeks) { option in
                    Button {
                        weeks = option.weeks
                    } label: {
                        HStack {
                            Text("\(option.weeks)-week streak").font(.headline)
                            Spacer()
                            Text(option.label).foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                                .stroke(weeks == option.weeks ? Theme.accent : .clear, lineWidth: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(weeks == option.weeks ? .isSelected : [])
                }
            }
            .padding(.top, 8)
            Spacer()
            Button("Commit to my goal") {
                env.settings.streakGoalWeeks = weeks
                env.saveSettings()
                next()
            }
            .buttonStyle(.primary)
            .accessibilityIdentifier("commitButton")
            Button("Maybe later", action: next)
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
                Text("Building your plan…").font(.title.bold())
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(checks.enumerated()), id: \.offset) { index, text in
                        HStack(spacing: 12) {
                            Image(systemName: index < revealed ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(index < revealed ? Theme.accent : Color.secondary)
                            Text(text).foregroundStyle(index < revealed ? .primary : .secondary)
                        }
                        .font(.headline)
                    }
                }
                Spacer()
            }
        }
        .animation(.snappy, value: revealed)
        .task {
            let s = env.settings
            let name = PlanRecommender.program(goal: s.goal, level: s.experience, weeklyTarget: s.weeklyTarget)
            program = env.templates.programs().first { $0.name == name }
            s.planProgram = name
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
                .font(.title.bold())
            VStack(alignment: .leading, spacing: 6) {
                Label("Recommended for you", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text(program.name).font(.largeTitle.bold())
                Text("\(s.experience.title) · \(s.goal.title) · \(s.weeklyTarget)× per week")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .card()
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(program.templates) { template in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name).font(.headline)
                            Text(template.orderedExercises.compactMap(\.exercise?.name).joined(separator: " · "))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .card()
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
