import SwiftUI

/// Full-screen active workout (appendix A.3). It can be minimized into the mini bar so
/// the user can check other tabs without ending the session.
struct ActiveWorkoutView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var isPickerPresented = false
    @State private var isReorderPresented = false
    @State private var isRenamePresented = false
    @State private var nameDraft = ""
    @State private var finishCheck: WorkoutStore.FinishCheck?
    @State private var isDiscardConfirmPresented = false

    private var store: WorkoutStore { env.workout }

    var body: some View {
        NavigationStack {
            Group {
                if let session = store.session {
                    content(session)
                } else {
                    ProgressView()
                }
            }
            .background(Theme.background)
            .toolbar { toolbar }
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $isPickerPresented) {
            ExercisePickerView(title: "Add exercises") { selected in
                store.addExercises(selected)
            }
            .environment(env)
        }
        .sheet(isPresented: $isReorderPresented) {
            ReorderExercisesView().environment(env)
        }
        .alert("Rename workout", isPresented: $isRenamePresented) {
            TextField("Workout name", text: $nameDraft)
            Button("Save") { store.rename(nameDraft) }
            Button("Cancel", role: .cancel) {}
        }
        .alert(finishAlertTitle, isPresented: finishAlertBinding, presenting: finishCheck) { check in
            switch check {
            case .nothingCompleted:
                Button("Discard workout", role: .destructive) { store.discard() }
                Button("Keep logging", role: .cancel) {}
            case .unfinishedFilledSets:
                Button("Mark all as done") {
                    store.completeFilledSets()
                    store.finish()
                }
                Button("Ignore unchecked sets") { store.finish() }
                Button("Cancel", role: .cancel) {}
            case .ready:
                EmptyView()
            }
        } message: { check in
            switch check {
            case .nothingCompleted:
                Text("No sets are checked yet, so there is nothing to save.")
            case .unfinishedFilledSets(let count):
                Text("\(count) filled sets aren't checked. Mark them as done or leave them out?")
            case .ready:
                EmptyView()
            }
        }
        .confirmationDialog("Discard this workout?", isPresented: $isDiscardConfirmPresented, titleVisibility: .visible) {
            Button("Discard workout", role: .destructive) { store.discard() }
        } message: {
            Text("All sets logged in this workout will be deleted.")
        }
        .alert(store.notice ?? "", isPresented: Binding(get: { store.notice != nil }, set: { if !$0 { store.notice = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private var finishAlertTitle: LocalizedStringKey {
        switch finishCheck {
        case .nothingCompleted: "Nothing to save"
        case .unfinishedFilledSets: "Unchecked sets"
        default: ""
        }
    }

    private var finishAlertBinding: Binding<Bool> {
        Binding(get: { finishCheck != nil && finishCheck != .ready }, set: { if !$0 { finishCheck = nil } })
    }

    private func content(_ session: WorkoutSession) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                WorkoutHeaderView(session: session, unit: env.unit)
                    .onTapGesture {
                        nameDraft = session.name
                        isRenamePresented = true
                    }
                ForEach(session.orderedExercises) { entry in
                    ExerciseCardView(entry: entry, onReorder: { isReorderPresented = true })
                }
                Button {
                    isPickerPresented = true
                } label: {
                    Label("Add exercise", systemImage: "plus")
                }
                .buttonStyle(.secondary)
                .accessibilityIdentifier("addExerciseButton")

                Button("Discard workout", role: .destructive) { isDiscardConfirmPresented = true }
                    .padding(.top, 8)
            }
            .padding()
            .padding(.bottom, 96)
        }
        .scrollDismissesKeyboard(.interactively)
        .overlay(alignment: .bottom) {
            RestTimerBar(timer: store.restTimer)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                store.isPresented = false
            } label: {
                Image(systemName: "chevron.down")
            }
            .accessibilityLabel("Minimize workout")
        }
        ToolbarItem(placement: .principal) {
            Text(store.session?.name ?? "")
                .font(.headline)
                .lineLimit(1)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Finish") {
                let check = store.finishCheck()
                if check == .ready { store.finish() } else { finishCheck = check }
            }
            .fontWeight(.semibold)
            .accessibilityIdentifier("finishWorkoutButton")
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }
}

/// LOG-10: running duration, volume, completed sets.
struct WorkoutHeaderView: View {
    var session: WorkoutSession
    var unit: WeightUnit

    var body: some View {
        TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
            HStack {
                StatTile(value: DurationFormatter.clock(Int(context.date.timeIntervalSince(session.startedAt))), label: "Duration")
                StatTile(value: WeightFormatter.volume(kg: session.totalVolumeKg, unit: unit), label: "Volume")
                StatTile(value: "\(session.completedSetCount)", label: "Sets")
            }
        }
        .card()
        .accessibilityHint("Double tap to rename the workout")
    }
}

/// Drag to reorder exercises (LOG-02).
struct ReorderExercisesView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(env.workout.session?.orderedExercises ?? []) { entry in
                    Text(entry.exercise?.name ?? "")
                }
                .onMove { env.workout.moveExercises(from: $0, to: $1) }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reorder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
