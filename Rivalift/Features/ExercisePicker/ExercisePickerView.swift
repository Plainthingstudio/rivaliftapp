import SwiftUI

/// LIB-02 / LIB-03 / appendix A.4: search, muscle and equipment chips, recent section,
/// multi-select and custom exercise creation.
struct ExercisePickerView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    var title: LocalizedStringKey
    var allowsMultipleSelection = true
    var onSelect: ([Exercise]) -> Void

    @State private var query = ""
    @State private var muscles: Set<MuscleGroup> = []
    @State private var equipment: Set<Equipment> = []
    @State private var selected: [Exercise] = []
    @State private var results: [Exercise] = []
    @State private var recent: [Exercise] = []
    @State private var isCreatePresented = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    filterChips
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                Group {
                    if query.isEmpty, muscles.isEmpty, equipment.isEmpty, !recent.isEmpty {
                        Section("Recent") {
                            ForEach(recent) { row($0) }
                        }
                    }
                    Section(query.isEmpty ? "All exercises" : "Results") {
                        if results.isEmpty {
                            Text("No exercises found").foregroundStyle(.secondary)
                        }
                        ForEach(results) { row($0) }
                    }
                }
                .listRowBackground(Theme.listRow)
            }
            .screenBackground()
            .listStyle(.insetGrouped)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search exercises")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("Create") { isCreatePresented = true } }
            }
            .safeAreaInset(edge: .bottom) {
                if allowsMultipleSelection {
                    Button("Add exercises (\(selected.count))") { commit() }
                        .buttonStyle(.primary)
                        .disabled(selected.isEmpty)
                        .padding()
                        .background(Theme.bottomFade)
                        .accessibilityIdentifier("addSelectedExercisesButton")
                }
            }
            .sheet(isPresented: $isCreatePresented) {
                CreateExerciseView { exercise in
                    reload()
                    toggle(exercise)
                }
                .environment(env)
            }
        }
        .onAppear {
            recent = env.exercises.recentExercises()
            reload()
        }
        .onChange(of: query) { _, _ in reload() }
        .onChange(of: muscles) { _, _ in reload() }
        .onChange(of: equipment) { _, _ in reload() }
    }

    private func reload() {
        results = env.exercises.search(query, muscles: muscles, equipment: equipment)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(muscles).sorted { $0.rawValue < $1.rawValue }) { muscle in
                    Chip(title: muscle.displayName, isActive: true) { muscles.remove(muscle) }
                }
                ForEach(Array(equipment).sorted { $0.rawValue < $1.rawValue }) { item in
                    Chip(title: item.displayName, isActive: true) { equipment.remove(item) }
                }
                Menu {
                    ForEach(MuscleGroup.allCases) { muscle in
                        Button(muscle.displayName) { muscles.insert(muscle) }
                    }
                } label: {
                    ChipLabel(title: String(localized: "Muscle"), isActive: false, systemImage: "chevron.down")
                }
                Menu {
                    ForEach(Equipment.allCases) { item in
                        Button(item.displayName) { equipment.insert(item) }
                    }
                } label: {
                    ChipLabel(title: String(localized: "Equipment"), isActive: false, systemImage: "chevron.down")
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
    }

    private func row(_ exercise: Exercise) -> some View {
        let isSelected = selected.contains { $0.id == exercise.id }
        return Button {
            toggle(exercise)
        } label: {
            HStack(spacing: 12) {
                ExerciseIcon(muscle: exercise.primaryMuscle, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name).foregroundStyle(.primary)
                    Text(exercise.subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.accent : Color.secondary)
            }
            .frame(minHeight: Theme.minTap)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .swipeActions {
            if exercise.isCustom {
                Button("Delete", role: .destructive) {
                    env.exercises.deleteCustom(exercise)
                    reload()
                }
            }
        }
    }

    private func toggle(_ exercise: Exercise) {
        if !allowsMultipleSelection {
            onSelect([exercise])
            dismiss()
            return
        }
        if let index = selected.firstIndex(where: { $0.id == exercise.id }) {
            selected.remove(at: index)
        } else {
            selected.append(exercise)
        }
    }

    private func commit() {
        onSelect(selected)
        dismiss()
    }
}

struct Chip: View {
    var title: String
    var isActive: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ChipLabel(title: title, isActive: isActive, systemImage: isActive ? "xmark" : nil)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isActive ? "Remove filter \(title)" : title)
    }
}

struct ChipLabel: View {
    var title: String
    var isActive: Bool
    var systemImage: String?

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            if let systemImage { Image(systemName: systemImage).font(.caption2.weight(.bold)) }
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 12)
        .frame(minHeight: 36)
        .foregroundStyle(isActive ? Color.white : Color.primary)
        .background(isActive ? Theme.accent : Theme.card, in: Capsule())
    }
}

/// LIB-03.
struct CreateExerciseView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    var onCreate: (Exercise) -> Void

    @State private var name = ""
    @State private var primary: MuscleGroup = .chest
    @State private var secondary: Set<MuscleGroup> = []
    @State private var equipment: Equipment = .barbell
    @State private var type: ExerciseType = .weightReps
    @State private var isCompound = false

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    TextField("Name", text: $name)
                    Picker("Primary muscle", selection: $primary) {
                        ForEach(MuscleGroup.allCases) { Text($0.displayName).tag($0) }
                    }
                    NavigationLink {
                        List(MuscleGroup.allCases.filter { $0 != primary }) { muscle in
                            Button {
                                if secondary.contains(muscle) { secondary.remove(muscle) } else { secondary.insert(muscle) }
                            } label: {
                                HStack {
                                    Text(muscle.displayName).foregroundStyle(.primary)
                                    Spacer()
                                    if secondary.contains(muscle) { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                                }
                            }
                            .listRowBackground(Theme.listRow)
                        }
                        .screenBackground()
                        .navigationTitle("Secondary muscles")
                    } label: {
                        LabeledContent("Secondary muscles", value: secondary.isEmpty ? "None" : secondary.map(\.displayName).sorted().joined(separator: ", "))
                    }
                    Picker("Equipment", selection: $equipment) {
                        ForEach(Equipment.allCases) { Text($0.displayName).tag($0) }
                    }
                    Picker("Type", selection: $type) {
                        ForEach(ExerciseType.allCases) { Text($0.displayName).tag($0) }
                    }
                    Toggle("Compound movement", isOn: $isCompound)
                    Section {
                        Text("Custom exercises can't be used as league categories because they can't be matched between friends.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Theme.listRow)
            }
            .screenBackground()
            .navigationTitle("New exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let exercise = env.exercises.createCustom(
                            name: name,
                            primaryMuscle: primary,
                            secondaryMuscles: Array(secondary),
                            equipment: equipment,
                            type: type,
                            isCompound: isCompound
                        )
                        onCreate(exercise)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).count < 2)
                }
            }
        }
    }
}
