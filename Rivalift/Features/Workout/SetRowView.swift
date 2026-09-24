import SwiftUI

/// One row of the set table: SET · PREVIOUS · weight · reps · check (appendix A.3).
struct SetRowView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let set: SetEntry
    let entry: SessionExercise

    @State private var weightText = ""
    @State private var repsText = ""
    @State private var repsHighlighted = false
    @State private var confirmation: Double?
    @FocusState private var focus: Field?

    private enum Field { case weight, reps }

    private var store: WorkoutStore { env.workout }
    private var unit: WeightUnit { env.unit }
    private var type: ExerciseType { entry.exercise?.type ?? .weightReps }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                stackedLayout
            } else {
                rowLayout
            }
        }
        .padding(.vertical, 2)
        .background(set.isCompleted ? Theme.completedRow : .clear, in: RoundedRectangle(cornerRadius: 8))
        .onAppear(perform: syncFromModel)
        .onChange(of: set.weightKg) { _, _ in if focus != .weight { syncFromModel() } }
        .onChange(of: set.reps) { _, _ in if focus != .reps { syncFromModel() } }
        .onChange(of: set.durationSec) { _, _ in if focus != .reps { syncFromModel() } }
        .onChange(of: unit) { _, _ in syncFromModel() }
        .onChange(of: weightText) { _, text in
            guard focus == .weight else { return }
            store.setWeight(set, displayValue: WeightFormatter.parse(text))
        }
        .onChange(of: repsText) { _, text in
            guard focus == .reps else { return }
            let value = Int(text.filter(\.isNumber))
            if type == .duration { store.setDuration(set, value) } else { store.setReps(set, value) }
            repsHighlighted = false
        }
        .alert("Did you mean \(confirmationText)?", isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } })) {
            Button("Use \(confirmationText)") {
                if let kg = confirmation {
                    store.setWeight(set, displayValue: UnitConverter.displayValue(kg, in: unit))
                    syncFromModel()
                    complete(confirmed: false)
                }
            }
            Button("Keep \(WeightFormatter.string(kg: set.weightKg, unit: unit, includeUnit: true))") {
                complete(confirmed: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("That's more than double your best on this exercise.")
        }
    }

    private var confirmationText: String {
        WeightFormatter.string(kg: confirmation ?? 0, unit: unit, includeUnit: true)
    }

    private var rowLayout: some View {
        HStack(spacing: 8) {
            setLabel.frame(width: 36)
            previousButton.frame(maxWidth: .infinity)
            weightField.frame(width: 72)
            repsField.frame(width: 56)
            checkButton
        }
    }

    /// Large Dynamic Type sizes stack the columns so they stay readable (section 14.7).
    private var stackedLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                setLabel
                previousButton
                Spacer()
                checkButton
            }
            HStack {
                weightField
                repsField
            }
        }
    }

    private var setLabel: some View {
        Menu {
            ForEach(SetType.allCases, id: \.self) { type in
                Button(type.displayName) { store.setType(set, type) }
            }
            Divider()
            Button("Delete set", role: .destructive) { store.removeSet(set) }
        } label: {
            HStack(spacing: 2) {
                Text(setTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(setTypeColor)
                if set.isPR { Image(systemName: "trophy.fill").font(.caption2).foregroundStyle(Theme.pr) }
            }
            .frame(minWidth: 36, minHeight: Theme.minTap)
        }
        .accessibilityLabel(set.isPR ? "Set \(setTitle), personal record" : "Set \(setTitle)")
    }

    private var setTitle: String {
        if let badge = set.setType.badge { return badge }
        let workingIndex = entry.orderedSets.filter { $0.setType.isWorking && $0.setType == .working }.firstIndex { $0.id == set.id }
        return "\((workingIndex ?? 0) + 1)"
    }

    private var setTypeColor: Color {
        switch set.setType {
        case .warmup: .orange
        case .drop: .purple
        case .failure: .red
        case .working: .primary
        }
    }

    private var previous: SetEntry? { store.previous(for: set, in: entry) }

    private var previousButton: some View {
        Button {
            if let previous { store.fillFromPrevious(set, previous: previous) }
        } label: {
            Text(previousText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: Theme.minTap)
        }
        .disabled(previous == nil || set.isCompleted)
        .accessibilityLabel(previous == nil ? "No previous set" : "Previous \(previousText). Double tap to fill.")
    }

    private var previousText: String {
        guard let previous else { return "—" }
        switch type {
        case .weightReps:
            return "\(WeightFormatter.string(kg: previous.weightKg, unit: unit)) × \(previous.reps)"
        case .bodyweightReps:
            return previous.weightKg > 0 ? "+\(WeightFormatter.string(kg: previous.weightKg, unit: unit)) × \(previous.reps)" : "\(previous.reps) reps"
        case .duration:
            return DurationFormatter.clock(previous.durationSec)
        }
    }

    private var weightPlaceholder: String {
        guard let kg = store.placeholderWeightKg(for: set, in: entry), kg > 0 else { return type == .weightReps ? "0" : "—" }
        return WeightFormatter.string(kg: kg, unit: unit)
    }

    private var repsPlaceholder: String {
        store.placeholderReps(for: set, in: entry).map(String.init) ?? "0"
    }

    private var weightField: some View {
        TextField(weightPlaceholder, text: $weightText)
            .keyboardType(.decimalPad)
            .focused($focus, equals: .weight)
            .multilineTextAlignment(.center)
            .font(.body.monospacedDigit().weight(.semibold))
            .frame(minHeight: Theme.minTap)
            .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 8))
            .disabled(set.isCompleted)
            .accessibilityLabel(Text("Weight in \(unit.symbol)"))
    }

    private var repsField: some View {
        TextField(repsPlaceholder, text: $repsText)
            .keyboardType(.numberPad)
            .focused($focus, equals: .reps)
            .multilineTextAlignment(.center)
            .font(.body.monospacedDigit().weight(.semibold))
            .frame(minHeight: Theme.minTap)
            .background(
                repsHighlighted ? Color.red.opacity(0.25) : Theme.elevated,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .disabled(set.isCompleted)
            .accessibilityLabel(type == .duration ? "Seconds" : "Reps")
    }

    private var checkButton: some View {
        Button {
            focus = nil
            complete(confirmed: false)
        } label: {
            Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                .font(.title2)
                .foregroundStyle(set.isCompleted ? Color.green : Color.secondary)
                .frame(width: Theme.minTap, height: Theme.minTap)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(set.isCompleted ? "Completed. Double tap to undo." : "Complete set")
        .accessibilityIdentifier("completeSetButton")
    }

    private func complete(confirmed: Bool) {
        switch store.toggleComplete(set, in: entry, confirmed: confirmed) {
        case .needsConfirmation(let suggestedKg):
            confirmation = suggestedKg
        case .rejected(.rejectMissingReps), .rejected(.rejectMissingDuration):
            withAnimation { repsHighlighted = true }
        case .completed, .uncompleted, .rejected:
            break
        }
        syncFromModel()
    }

    private func syncFromModel() {
        weightText = set.hasWeight ? WeightFormatter.string(kg: set.weightKg, unit: unit) : ""
        if set.hasReps {
            repsText = type == .duration ? String(set.durationSec) : String(set.reps)
        } else {
            repsText = ""
        }
    }
}
