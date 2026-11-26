import SwiftUI

/// ⇄ on a plan exercise: pick an alternative for the same muscles, today only or for good.
struct SwapSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    let item: TemplateExercise

    @State private var options: [Exercise] = []
    @State private var selection: Exercise?
    @State private var always = false

    var body: some View {
        let current = env.planExercise(for: item)
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ExercisePhoto(exercise: current, width: 56, height: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Swap \(current?.name ?? "")").font(.title3.weight(.medium))
                    Text("Machine taken or doesn't feel right? These train the same muscles: \(muscles(current)).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)

            if options.isEmpty {
                Text("No other exercises train these muscles yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 6) {
                ForEach(options) { exercise in
                    optionRow(exercise)
                }
            }

            PillPicker(selection: $always, options: [(false, "Just today"), (true, "Always in my plan")])
                .frame(maxWidth: .infinity)

            Button(selection.map { String(localized: "Swap to \($0.name)") } ?? String(localized: "Swap")) {
                if let selection { env.swap(item, to: selection, always: always) }
                dismiss()
            }
            .buttonStyle(.primary)
            .disabled(selection == nil)
            .accessibilityIdentifier("confirmSwap")
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.large])
        .presentationBackground(.black)
        .onAppear {
            options = env.swapCandidates(for: item)
            selection = options.first
        }
    }

    private func optionRow(_ exercise: Exercise) -> some View {
        let selected = selection?.id == exercise.id
        return Button {
            selection = exercise
        } label: {
            HStack(spacing: 12) {
                ExercisePhoto(exercise: exercise, width: 56, height: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name).font(.callout.weight(.medium))
                    Text("\(exercise.equipment.displayName) · \(item.setCount) × \(item.targetReps)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.accent : .secondary)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .background(.white.opacity(selected ? 0.1 : 0.04), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(selected ? Theme.accent.opacity(0.6) : Theme.border))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func muscles(_ exercise: Exercise?) -> String {
        guard let exercise else { return "" }
        return ([exercise.primaryMuscle] + exercise.secondaryMuscles.prefix(1))
            .map { $0.displayName.lowercased() }
            .formatted(.list(type: .and))
    }
}
