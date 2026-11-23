import SwiftUI

/// Library tab: plans, exercises and the user's own workouts in one place.
struct LibraryView: View {
    @State private var segment: Segment = .plans

    enum Segment: Hashable { case plans, exercises, workouts }

    var body: some View {
        Group {
            switch segment {
            case .plans: LibraryPlansView()
            case .exercises: ExerciseLibraryView()
            case .workouts: TemplatesView(showsPrograms: false)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            PillPicker(selection: $segment, options: [(.plans, "Plans"), (.exercises, "Exercises"), (.workouts, "My workouts")])
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Your current plan, then every built-in plan with what it is for.
private struct LibraryPlansView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var plan: AppEnvironment.PlanHome?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let plan {
                    caption("CURRENT PLAN")
                    NavigationLink { PlanView() } label: {
                        card(title: plan.title, subtitle: String(localized: "Week \(plan.progress.week) of \(plan.progress.weeks) · \(plan.subtitle)"), chips: [], highlighted: true)
                    }
                    .buttonStyle(.plain)
                }
                caption("ALL PLANS").padding(.top, 8)
                ForEach(env.templates.programs()) { program in
                    let info = AppEnvironment.programInfo(for: program.name)
                    NavigationLink { ProgramDetailView(program: program) } label: {
                        card(title: AppEnvironment.splitName(for: program.name), subtitle: info.summary, chips: info.chips, highlighted: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("program-\(program.name)")
                }
            }
            .padding()
        }
        .screenBackground()
        .onAppear { plan = env.planHome() }
    }

    private func caption(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.horizontal, 4)
    }

    private func card(title: String, subtitle: String, chips: [String], highlighted: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline.weight(.medium))
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                }
                if !chips.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(chips, id: \.self) { chip in
                            Text(chip)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .overlay(Capsule().strokeBorder(Theme.border))
                        }
                    }
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").foregroundStyle(.secondary).accessibilityHidden(true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { if highlighted { Theme.accent.opacity(0.12) } }
        .glassCard(cornerRadius: 24)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// A built-in plan: what it is for, its workouts, and starting it.
struct ProgramDetailView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    let program: TemplateRepository.Program

    var body: some View {
        let info = AppEnvironment.programInfo(for: program.name)
        let isCurrent = program.name == env.settings.planProgram
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppEnvironment.splitName(for: program.name)).font(.largeTitle)
                    Text(info.summary).font(.subheadline).foregroundStyle(.secondary)
                    Text(info.chips.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                }
                ForEach(Array(program.templates.enumerated()), id: \.element.id) { index, workout in
                    NavigationLink { TemplateDetailView(template: workout) } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Day \(index + 1) · \(workout.name)").font(.headline.weight(.medium))
                                    Text("\(workout.orderedExercises.count) exercises · \(workout.estimatedDurationMin) min")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.secondary).accessibilityHidden(true)
                            }
                            HStack(spacing: 6) {
                                ForEach(workout.orderedExercises.prefix(5)) { ExercisePhoto(exercise: $0.exercise, width: 52, height: 40) }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard(cornerRadius: 24)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Group {
                if isCurrent {
                    Button("This is your plan") {}.buttonStyle(.secondary).disabled(true)
                } else {
                    Button("Start this plan") { start() }
                        .buttonStyle(.primary)
                        .accessibilityIdentifier("startThisPlan")
                }
            }
            .padding(.horizontal)
            .padding(.top, 28)
            .padding(.bottom, 8)
            .background(Theme.bottomFade)
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The new plan starts this week and shows on Home.
    private func start() {
        env.settings.planProgram = program.name
        env.settings.planStartedAt = Date()
        env.settings.daySwapsRaw = ""
        env.settings.homeMode = .plan
        env.saveSettings()
        dismiss()
        env.selectedTab = .home
    }
}
