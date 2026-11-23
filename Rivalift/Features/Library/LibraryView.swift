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

/// Your current plan, then every plan named for what it does.
private struct LibraryPlansView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var home: AppEnvironment.PlanHome?

    var body: some View {
        let current = env.currentPlan
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let home {
                    caption("CURRENT PLAN")
                    NavigationLink { PlanView() } label: {
                        PlanCatalogCard(plan: current, detail: String(localized: "Week \(home.progress.week) of \(home.progress.weeks) · \(home.subtitle)"), isCurrent: true)
                    }
                    .buttonStyle(.plain)
                }
                caption("ALL PLANS").padding(.top, 8)
                ForEach(PlanCatalog.all.filter { $0.id != current.id || home == nil }) { plan in
                    NavigationLink { PlanDetailView(plan: plan) } label: {
                        PlanCatalogCard(plan: plan)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("plan-\(plan.id)")
                }
            }
            .padding()
        }
        .screenBackground()
        .onAppear { home = env.planHome() }
        .onChange(of: env.dataVersion) { _, _ in home = env.planHome() }
    }

    private func caption(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.horizontal, 4)
    }
}

/// A plan in a list: name, what it does, and days, weeks and level chips.
struct PlanCatalogCard: View {
    let plan: TrainingPlan
    /// Replaces the chips, e.g. "Week 2 of 8 · Full body · 3 days a week" for the current plan.
    var detail: String?
    var isCurrent = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title).font(.headline.weight(.medium))
                    Text(detail ?? plan.summary).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                }
                if detail == nil {
                    HStack(spacing: 6) {
                        ForEach([plan.daysText, String(localized: "\(plan.weeks) weeks"), plan.levelName], id: \.self) { chip in
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
            Image(systemName: isCurrent ? "checkmark.circle.fill" : "chevron.right")
                .foregroundStyle(isCurrent ? Theme.accent : .secondary)
                .accessibilityHidden(true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { if isCurrent { Theme.accent.opacity(0.12) } }
        .glassCard(cornerRadius: 24)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}

/// A plan before starting it: what it does and the workouts inside it for your weekly target.
struct PlanDetailView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    let plan: TrainingPlan

    var body: some View {
        let isCurrent = plan.id == env.currentPlan.id && env.planHome() != nil
        let programName = plan.program(daysPerWeek: env.settings.effectiveWeeklyTarget())
        let program = env.templates.programs().first { $0.name == programName }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title).font(.largeTitle)
                    Text(plan.summary).font(.subheadline).foregroundStyle(.secondary)
                    Text("\(plan.daysText) · \(plan.weeks) weeks · \(plan.levelName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                Text("What's inside: \(AppEnvironment.splitName(for: programName))")
                    .font(.headline.weight(.medium))
                    .padding(.top, 8)
                ForEach(Array((program?.templates ?? []).enumerated()), id: \.element.id) { index, workout in
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
                    Button("Start this plan") {
                        env.startPlan(plan)
                        dismiss()
                        env.selectedTab = .home
                    }
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
}
