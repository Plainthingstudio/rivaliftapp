import SwiftUI

/// Template preview before starting: every exercise with sets × reps and rest.
struct TemplateDetailView: View {
    @Environment(AppEnvironment.self) private var env
    let template: WorkoutTemplate

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    if !template.programName.isEmpty {
                        Text(template.programName).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("\(template.orderedExercises.count) exercises · \(template.totalSets) sets · ~\(template.estimatedDurationMin) min")
                        .font(.subheadline.weight(.semibold))
                }
                .listRowBackground(Color.clear)
            }
            Section("Exercises") {
                ForEach(template.orderedExercises) { item in
                    HStack(spacing: 12) {
                        if let exercise = item.exercise {
                            ExerciseIcon(muscle: exercise.primaryMuscle)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.exercise?.name ?? "").font(.headline)
                            if let exercise = item.exercise {
                                Text(exercise.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                            Text(prescription(item)).font(.subheadline)
                        }
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            Button {
                env.workout.requestStart(.template(template.id))
            } label: {
                Label("Start \(template.name)", systemImage: "play.fill")
            }
            .buttonStyle(.primary)
            .padding()
            .background(.bar)
            .accessibilityIdentifier("startTemplateButton")
        }
    }

    private func prescription(_ item: TemplateExercise) -> String {
        let rest = String(localized: "Rest \(DurationFormatter.clock(item.restSec))")
        if item.exercise?.type == .duration || item.targetReps == 0 {
            return String(localized: "\(item.setCount) sets · \(rest)")
        }
        return String(localized: "\(item.setCount) sets × \(item.targetReps) reps · \(rest)")
    }
}
