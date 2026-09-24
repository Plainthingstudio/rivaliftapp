import SwiftUI

/// One exercise in the active workout with its set table (LOG-03).
struct ExerciseCardView: View {
    @Environment(AppEnvironment.self) private var env
    let entry: SessionExercise
    var onReorder: () -> Void

    @State private var isRemoveConfirmPresented = false
    @State private var isReplacePresented = false
    @State private var isRestPickerPresented = false
    @State private var isNotesVisible = false
    @State private var notesDraft = ""

    private var store: WorkoutStore { env.workout }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if isNotesVisible || !entry.notes.isEmpty {
                TextField("Notes", text: $notesDraft, axis: .vertical)
                    .font(.subheadline)
                    .textFieldStyle(.roundedBorder)
                    .onAppear { notesDraft = entry.notes }
                    .onChange(of: notesDraft) { _, value in store.setNotes(entry, value) }
            }
            columnHeader
            ForEach(entry.orderedSets) { set in
                SetRowView(set: set, entry: entry)
                    .swipeToDelete { store.removeSet(set) }
            }
            Button {
                store.addSet(to: entry)
            } label: {
                Label("Add set", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: Theme.minTap)
            }
            .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 10))
        }
        .card()
        .confirmationDialog("Remove exercise?", isPresented: $isRemoveConfirmPresented, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { store.removeExercise(entry) }
        } message: {
            Text("Completed sets of this exercise will be deleted.")
        }
        .sheet(isPresented: $isReplacePresented) {
            ExercisePickerView(title: "Replace exercise", allowsMultipleSelection: false) { selected in
                if let exercise = selected.first { store.replaceExercise(entry, with: exercise) }
            }
            .environment(env)
        }
        .sheet(isPresented: $isRestPickerPresented) {
            RestDurationPicker(seconds: entry.restSec) { store.setRest(entry, seconds: $0) }
                .presentationDetents([.medium])
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ExerciseIcon(muscle: entry.exercise?.primaryMuscle ?? .fullBody)
            VStack(alignment: .leading, spacing: 2) {
                if let exercise = entry.exercise {
                    NavigationLink {
                        ExerciseDetailView(exercise: exercise)
                    } label: {
                        Text(exercise.name)
                            .font(.headline)
                            .foregroundStyle(Theme.accent)
                            .multilineTextAlignment(.leading)
                    }
                }
                Label("Rest \(DurationFormatter.clock(entry.restSec))", systemImage: "timer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Button("Replace exercise", systemImage: "arrow.triangle.2.circlepath") { isReplacePresented = true }
                Button("Rest timer", systemImage: "timer") { isRestPickerPresented = true }
                Button("Add note", systemImage: "note.text") { isNotesVisible = true }
                Button("Reorder exercises", systemImage: "arrow.up.arrow.down") { onReorder() }
                Button("Remove exercise", systemImage: "trash", role: .destructive) {
                    if store.needsConfirmationToRemove(entry) {
                        isRemoveConfirmPresented = true
                    } else {
                        store.removeExercise(entry)
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: Theme.minTap, height: Theme.minTap)
            }
            .accessibilityLabel("Exercise options")
        }
    }

    private var columnHeader: some View {
        let type = entry.exercise?.type ?? .weightReps
        let weightTitle: String = {
            let unit = env.unit.columnTitle
            switch type {
            case .weightReps: return entry.exercise?.isPerDumbbell == true ? "\(unit) / DB" : unit
            case .bodyweightReps, .duration: return "+\(unit)"
            }
        }()
        return HStack(spacing: 8) {
            Text("SET").frame(width: 36)
            Text("PREVIOUS").frame(maxWidth: .infinity)
            Text(weightTitle).frame(width: 72)
            Text(type == .duration ? "SEC" : "REPS").frame(width: 56)
            Image(systemName: "checkmark").frame(width: Theme.minTap)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }
}

private struct SwipeToDelete: ViewModifier {
    var action: () -> Void
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive, action: {
                withAnimation { offset = 0 }
                action()
            }) {
                Image(systemName: "trash")
                    .foregroundStyle(.white)
                    .frame(width: 64, height: Theme.minTap)
                    .background(.red, in: RoundedRectangle(cornerRadius: 8))
            }
            .opacity(offset < 0 ? 1 : 0)
            .accessibilityLabel("Delete set")

            content
                .background(Theme.card)
                .offset(x: offset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            if abs(value.translation.width) > abs(value.translation.height) {
                                offset = min(0, max(value.translation.width, -80))
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.snappy) { offset = offset < -40 ? -72 : 0 }
                        }
                )
        }
        .accessibilityAction(named: "Delete set", action)
    }
}

extension View {
    func swipeToDelete(_ action: @escaping () -> Void) -> some View {
        modifier(SwipeToDelete(action: action))
    }
}

struct RestDurationPicker: View {
    @State var seconds: Int
    var onSave: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    private let options = Array(stride(from: 0, through: 300, by: 15))

    var body: some View {
        NavigationStack {
            Picker("Rest", selection: $seconds) {
                ForEach(options, id: \.self) { value in
                    Text(value == 0 ? String(localized: "Off") : DurationFormatter.clock(value)).tag(value)
                }
            }
            .pickerStyle(.wheel)
            .navigationTitle("Rest timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(seconds)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}
