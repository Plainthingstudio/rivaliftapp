import SwiftUI

/// Template preview before starting: every exercise with sets × reps and rest.
struct TemplateDetailView: View {
    @Environment(AppEnvironment.self) private var env
    let template: WorkoutTemplate

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    if !template.programName.isEmpty {
                        Text(template.programName).padding(.horizontal, 4)
                    }
                    HStack(spacing: 8) {
                        stat("\(template.orderedExercises.count)", "Exercises")
                        stat("\(template.totalSets)", "Sets")
                        stat("\(template.estimatedDurationMin)", "Minute")
                    }
                }
                Button {
                    env.workout.requestStart(.template(template.id))
                } label: {
                    HStack(spacing: 6) {
                        Image("IconPlay").accessibilityHidden(true)
                        Text("Start \(template.name)")
                    }
                }
                .buttonStyle(.primary)
                .accessibilityIdentifier("startTemplateButton")
                Text("Exercises").padding(.horizontal, 4)
                ForEach(Array(template.orderedExercises.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Rectangle().fill(.white.opacity(0.1)).frame(height: 0.5) }
                    row(item)
                }
            }
            .padding()
        }
        .screenBackground()
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.large)
    }

    /// Figma "Stat": red rounded square with a number and a label.
    private func stat(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title2).monospacedDigit()
            Text(label).font(.caption.weight(.light)).foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .redCard(cornerRadius: 36)
        .accessibilityElement(children: .combine)
    }

    private func row(_ item: TemplateExercise) -> some View {
        HStack(spacing: 8) {
            ExercisePhoto(exercise: item.exercise)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .dotTexture("DotGridWeek", alignment: .center, x: 14, y: -143.46)
                .glassCard(cornerRadius: 24)
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.exercise?.name ?? "").font(.callout).lineLimit(2)
                    if let exercise = item.exercise {
                        DividedText(parts: [exercise.primaryMuscle.displayName, exercise.equipment.displayName])
                    }
                }
                HStack(spacing: 4) {
                    InfoChip(icon: "Icon_chip_repeat", text: setsText(item))
                    InfoChip(icon: "Icon_chip_timer", text: String(localized: "Rest \(DurationFormatter.clock(item.restSec))"))
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func setsText(_ item: TemplateExercise) -> String {
        if item.exercise?.type == .duration || item.targetReps == 0 {
            return String(localized: "\(item.setCount) sets")
        }
        return String(localized: "\(item.setCount) sets x \(item.targetReps) reps")
    }

}
