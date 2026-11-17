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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    filterChips
                    if query.isEmpty, muscles.isEmpty, equipment.isEmpty, !recent.isEmpty {
                        Text("Recent").padding(.horizontal, 4).padding(.top, 6)
                        ForEach(recent) { row($0) }
                    }
                    Text(query.isEmpty ? "All exercises" : "Results").padding(.horizontal, 4).padding(.top, 6)
                    if results.isEmpty {
                        Text("No exercises found").font(.subheadline).foregroundStyle(.secondary).padding(.horizontal, 4)
                    }
                    ForEach(results) { row($0) }
                }
                .padding()
            }
            .screenBackground()
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
            ExerciseRowCard(exercise: exercise, isSelected: allowsMultipleSelection ? isSelected : nil)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if exercise.isCustom {
                Button("Delete", systemImage: "trash", role: .destructive) {
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
        FilterPill(title: title, isSelected: isActive, systemImage: systemImage)
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
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    GlassSection("Name") {
                        TextField("Name", text: $name).glassField()
                    }
                    GlassSection("Details", footer: Text("Custom exercises can't be used as league categories because they can't be matched between friends.")) {
                        GlassRow(title: "Primary muscle") {
                            Menu {
                                Picker("Primary muscle", selection: $primary) {
                                    ForEach(MuscleGroup.allCases) { Text($0.displayName).tag($0) }
                                }
                            } label: { PillMenuLabel(text: primary.displayName) }
                        }
                        GlassDivider()
                        NavigationLink {
                            SecondaryMusclesView(primary: primary, selection: $secondary)
                        } label: {
                            GlassRow(title: "Secondary muscles") {
                                Text(secondary.isEmpty ? String(localized: "None") : secondary.map(\.displayName).sorted().joined(separator: ", "))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Image("IconChevronCircle").accessibilityHidden(true)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        GlassDivider()
                        GlassRow(title: "Equipment") {
                            Menu {
                                Picker("Equipment", selection: $equipment) {
                                    ForEach(Equipment.allCases) { Text($0.displayName).tag($0) }
                                }
                            } label: { PillMenuLabel(text: equipment.displayName) }
                        }
                        GlassDivider()
                        GlassRow(title: "Type") {
                            Menu {
                                Picker("Type", selection: $type) {
                                    ForEach(ExerciseType.allCases) { Text($0.displayName).tag($0) }
                                }
                            } label: { PillMenuLabel(text: type.displayName) }
                        }
                        GlassDivider()
                        GlassRow(title: "Compound movement") {
                            Toggle("Compound movement", isOn: $isCompound).labelsHidden().tint(.green)
                        }
                    }
                }
                .padding()
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

/// Secondary muscles for a custom exercise, as check rows in a glass card.
private struct SecondaryMusclesView: View {
    let primary: MuscleGroup
    @Binding var selection: Set<MuscleGroup>

    var body: some View {
        let options = MuscleGroup.allCases.filter { $0 != primary }
        ScrollView {
            GlassCard {
                ForEach(Array(options.enumerated()), id: \.element) { index, muscle in
                    if index > 0 { GlassDivider() }
                    GlassChoiceRow(isSelected: selection.contains(muscle), action: {
                        if selection.contains(muscle) { selection.remove(muscle) } else { selection.insert(muscle) }
                    }) {
                        Text(muscle.displayName)
                    } detail: {
                        EmptyView()
                    }
                }
            }
            .padding()
        }
        .screenBackground()
        .navigationTitle("Secondary muscles")
        .navigationBarTitleDisplayMode(.inline)
    }
}
