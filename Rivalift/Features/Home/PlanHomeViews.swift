import SwiftUI

/// "Your plan": goal name, split, week of the plan and workouts done.
struct PlanCard: View {
    let plan: AppEnvironment.PlanHome

    var body: some View {
        let progress = plan.progress
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("YOUR PLAN").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("Week \(progress.week) of \(progress.weeks)").font(.caption)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.title).font(.title2)
                Text(plan.subtitle).font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                ForEach(0..<progress.weeks, id: \.self) { index in
                    WeekSegment(fill: fill(week: index))
                }
            }
            .accessibilityHidden(true)
            Text("\(progress.done) of \(progress.total) workouts done")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .accessibilityElement(children: .combine)
    }

    /// Past weeks full, this week by workouts done, later weeks empty.
    private func fill(week index: Int) -> Double {
        let current = plan.progress.week - 1
        if index < current { return 1 }
        if index > current { return 0 }
        return min(1, Double(plan.doneThisWeek) / Double(max(plan.daysPerWeek, 1)))
    }

    private struct WeekSegment: View {
        let fill: Double

        var body: some View {
            GeometryReader { geo in
                Capsule().fill(.white.opacity(0.15))
                    .overlay(alignment: .leading) {
                        Capsule().fill(Theme.primaryGradient).frame(width: geo.size.width * fill)
                    }
            }
            .frame(height: 6)
        }
    }
}

/// Monday to Sunday: done, today, planned and rest days, with the workout of each day.
struct PlanWeekStrip: View {
    let plan: AppEnvironment.PlanHome

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(plan.week.days.enumerated()), id: \.offset) { _, day in
                column(day)
            }
        }
    }

    private func column(_ day: PlanWeek.Day) -> some View {
        let isToday = day.date == plan.week.today.date
        let label = Self.shortLabel(plan.workout(day.workoutID)?.name)
        return VStack(spacing: 5) {
            Text(isToday ? String(localized: "Today") : day.date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption2.weight(isToday ? .semibold : .regular))
                .foregroundStyle(isToday ? .primary : .secondary)
            marker(day.state)
            Text(day.state == .rest ? String(localized: "Rest") : day.state == .missed ? String(localized: "Missed") : label)
                .font(.caption2)
                .foregroundStyle(day.state == .rest || day.state == .missed ? .tertiary : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background {
            if isToday {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accent.opacity(0.16))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.accent.opacity(0.45)))
            } else if day.state != .rest {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.04))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(day, label: label))
    }

    @ViewBuilder
    private func marker(_ state: PlanWeek.State) -> some View {
        switch state {
        case .done:
            Circle().fill(Theme.primaryGradient).frame(width: 26, height: 26)
                .overlay { Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(.white) }
        case .today:
            Circle().strokeBorder(Theme.accent, lineWidth: 2).frame(width: 26, height: 26)
        case .upcoming:
            Circle().strokeBorder(.white.opacity(0.2), lineWidth: 2).frame(width: 26, height: 26)
        case .missed:
            Circle().strokeBorder(.white.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])).frame(width: 26, height: 26)
        case .rest:
            Circle().fill(.white.opacity(0.16)).frame(width: 6, height: 6).frame(width: 26, height: 26)
        }
    }

    private func accessibilityText(_ day: PlanWeek.Day, label: String) -> String {
        let weekday = day.date.formatted(.dateTime.weekday(.wide))
        return switch day.state {
        case .done: String(localized: "\(weekday), \(label), done")
        case .today: String(localized: "Today, \(label)")
        case .upcoming: String(localized: "\(weekday), \(label)")
        case .missed: String(localized: "\(weekday), missed")
        case .rest: String(localized: "\(weekday), rest day")
        }
    }

    /// "Upper A" → "Upper", "Full Body A" → "A", "Push" → "Push": fits a seventh of the screen.
    // ponytail: name-based; give templates a short label field if names stop following this
    static func shortLabel(_ name: String?) -> String {
        guard let name else { return "" }
        var words = name.split(separator: " ")
        guard words.count > 1, let last = words.last, last.count == 1 else { return name }
        words.removeLast()
        let rest = words.joined(separator: " ")
        return rest.count > 6 ? String(last) : rest
    }
}

/// Today's workout from the plan, or a rest/done card with what comes next.
struct PlanToday: View {
    @Environment(AppEnvironment.self) private var env
    let plan: AppEnvironment.PlanHome
    @State private var swapping: TemplateExercise?

    var body: some View {
        switch plan.week.today.state {
        case .today:
            if let workout = plan.workout(plan.week.today.workoutID) { todayWorkout(workout) }
        case .done:
            status(icon: "checkmark.circle.fill", title: "Today's workout is done", text: "Nice work. Rest up for the next one.")
            nextUp
        default:
            status(
                icon: "moon.zzz.fill",
                title: "Rest day",
                text: "Your muscles grow while you recover. \(plan.doneThisWeek) of \(plan.daysPerWeek) workouts done this week."
            )
            nextUp
        }
    }

    private func todayWorkout(_ workout: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today · \(workout.name)").font(.title3)
                Spacer()
                Text("\(workout.orderedExercises.count) exercises · \(workout.estimatedDurationMin) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            VStack(spacing: 0) {
                ForEach(Array(workout.orderedExercises.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Rectangle().fill(Theme.border).frame(height: 0.5) }
                    if let exercise = env.planExercise(for: item) {
                        exerciseRow(item, exercise: exercise)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .glassCard()
            NavigationLink { PlanView() } label: {
                Label("Edit plan", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: Theme.minTap)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("editPlanLink")
        }
        .sheet(item: $swapping) { SwapSheet(item: $0) }
    }

    private func exerciseRow(_ item: TemplateExercise, exercise: Exercise) -> some View {
        HStack(spacing: 4) {
            NavigationLink { ExerciseDetailView(exercise: exercise) } label: {
                HStack(spacing: 12) {
                    ExercisePhoto(exercise: exercise, width: 56, height: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name).font(.subheadline)
                        Text(env.prescription(for: item)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
                .accessibilityElement(children: .combine)
            }
            .buttonStyle(.plain)
            Button { swapping = item } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.subheadline)
                    .frame(width: Theme.minTap, height: Theme.minTap)
                    .background(Theme.glassFill, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.border))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Swap \(exercise.name)")
            .accessibilityIdentifier("swapExercise")
        }
    }

    private func status(icon: String, title: LocalizedStringKey, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Theme.accent)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.accent.opacity(0.14)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title3)
                Text(text).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .glassCard()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var nextUp: some View {
        let day = plan.week.nextDay
        if let workout = plan.workout(day?.workoutID ?? plan.week.nextWorkoutID) {
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    if let day {
                        Text("NEXT UP · \(day.date.formatted(.dateTime.weekday(.wide)).uppercased())")
                    } else {
                        Text("NEXT UP")
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                NavigationLink { TemplateDetailView(template: workout) } label: {
                    HStack(spacing: 12) {
                        ExercisePhoto(exercise: workout.orderedExercises.first?.exercise, width: 56, height: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workout.name).font(.callout)
                            Text(workout.orderedExercises.prefix(3).compactMap(\.exercise?.name).joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image("IconChevronCircle").accessibilityHidden(true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                    .glassCard()
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Pinned at the bottom of Home: start today's plan workout, or train anyway on a rest day.
struct PlanStartButton: View {
    @Environment(AppEnvironment.self) private var env
    let plan: AppEnvironment.PlanHome

    var body: some View {
        Group {
            if env.workout.session != nil {
                Button("Resume workout") { env.workout.isPresented = true }
                    .buttonStyle(.primary)
            } else if plan.week.today.state == .today, let workout = plan.workout(plan.week.today.workoutID) {
                Button { env.workout.requestStart(.template(workout.id, swaps: env.todaySwaps())) } label: {
                    HStack(spacing: 6) {
                        Image("IconPlay").accessibilityHidden(true)
                        Text("Start today's workout")
                    }
                }
                .buttonStyle(.primary)
                .accessibilityIdentifier("startPlanWorkout")
            } else if let workout = plan.workout(plan.week.nextWorkoutID) {
                Button("Train anyway · \(workout.name)") { env.workout.requestStart(.template(workout.id, swaps: env.todaySwaps())) }
                    .buttonStyle(.secondary)
                    .accessibilityIdentifier("startPlanWorkout")
            }
        }
        .padding(.horizontal)
        .padding(.top, 28)
        .padding(.bottom, 8)
        .background(Theme.bottomFade)
    }
}
