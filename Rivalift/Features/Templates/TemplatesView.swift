import SwiftUI

/// LIB-04 … LIB-06 / appendix A.8.
struct TemplatesView: View {
    @Environment(AppEnvironment.self) private var env
    /// False in Library, where plans have their own tab.
    var showsPrograms = true
    /// Opens on Programs, e.g. from Home's "Create workout › From a ready-made workout".
    var opensPrograms = false
    @State private var segment: Segment = .mine
    @State private var mine: [WorkoutTemplate] = []
    @State private var programs: [TemplateRepository.Program] = []
    @State private var editing: WorkoutTemplate?
    @State private var toDelete: WorkoutTemplate?
    @State private var didPickSegment = false

    enum Segment: Hashable { case mine, programs }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if showsPrograms {
                    PillPicker(selection: $segment, options: [(.mine, "My routines"), (.programs, "Ready-made")])
                        .frame(maxWidth: .infinity)
                }
                switch segment {
                case .mine:
                    if mine.isEmpty {
                        Text("Build a routine, add a ready-made one, or save a finished workout as a routine.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                    }
                    cards(mine, editable: true)
                case .programs:
                    ForEach(programs) { program in
                        Text(program.name).padding(.horizontal, 8).padding(.top, 10)
                        cards(program.templates, editable: false)
                    }
                }
            }
            .padding()
        }
        .screenBackground()
        .navigationTitle(showsPrograms ? "Routines" : "Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New routine", systemImage: "plus") {
                    editing = env.templates.create(name: "")
                }
                .tint(.white)
            }
        }
        .navigationDestination(item: $editing) { template in
            TemplateEditorView(template: template)
        }
        .confirmationDialog("Delete template?", isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let toDelete { env.templates.delete(toDelete) }
                reload()
            }
        }
        .onAppear {
            reload()
            // Only on first appear, so coming back from the editor keeps the chosen tab.
            if !didPickSegment, showsPrograms, opensPrograms || mine.isEmpty { segment = .programs }
            didPickSegment = true
        }
    }

    private func cards(_ templates: [WorkoutTemplate], editable: Bool) -> some View {
        ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
            if index > 0 { Rectangle().fill(.white.opacity(0.1)).frame(height: 0.5) }
            TemplateCard(template: template, onEdit: editable ? { editing = template } : nil, onDuplicate: {
                env.templates.duplicate(template)
                if !editable { segment = .mine }
                reload()
            }, onDelete: editable ? { toDelete = template } : nil)
        }
    }

    private func reload() {
        mine = env.templates.userTemplates()
        // The user's plan first, then the other programs in seed order.
        let all = env.templates.programs()
        programs = all.filter { $0.name == env.settings.planProgram } + all.filter { $0.name != env.settings.planProgram }
    }
}

/// A template in the list; long-press for edit, duplicate and delete.
struct TemplateCard: View {
    let template: WorkoutTemplate
    var onEdit: (() -> Void)?
    var onDuplicate: () -> Void
    var onDelete: (() -> Void)?

    var body: some View {
        NavigationLink {
            TemplateDetailView(template: template)
        } label: {
            TemplateRowCard(template: template)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onEdit { Button("Edit", systemImage: "pencil", action: onEdit) }
            Button("Duplicate", systemImage: "plus.square.on.square", action: onDuplicate)
            if let onDelete { Button("Delete", systemImage: "trash", role: .destructive, action: onDelete) }
        }
    }
}

/// Figma "Template - Programs / Card": name, first exercises, sets and duration chips.
struct TemplateRowCard: View {
    let template: WorkoutTemplate

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name).font(.callout)
                    DividedText(parts: Array(template.orderedExercises.compactMap(\.exercise?.name).prefix(3)))
                }
                HStack(spacing: 4) {
                    InfoChip(icon: "Icon_chip_repeat", text: String(localized: "\(template.totalSets) sets"), fill: Color(red: 64 / 255, green: 87 / 255, blue: 235 / 255).opacity(0.24))
                    InfoChip(icon: "Icon_chip_clock", text: String(localized: "\(template.estimatedDurationMin) min"), fill: Color(red: 64 / 255, green: 87 / 255, blue: 235 / 255).opacity(0.24))
                }
            }
            Spacer(minLength: 8)
            Image("IconChevronCircle").accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Create and edit a user template: exercises, sets, target reps, rest (LIB-06).
struct TemplateEditorView: View {
    @Environment(AppEnvironment.self) private var env
    @Bindable var template: WorkoutTemplate
    @State private var isPickerPresented = false
    @State private var replacing: TemplateExercise?
    @State private var editMode: EditMode = .inactive
    @FocusState private var isNameFocused: Bool
    /// A routine just created (no name, no exercises): "New routine", name field focused, and
    /// thrown away if left without exercises.
    @State private var isNew: Bool

    init(template: WorkoutTemplate) {
        self.template = template
        _isNew = State(initialValue: template.name.isEmpty && template.orderedExercises.isEmpty)
    }

    var body: some View {
        List {
            Section {
                TextField("Name your routine", text: $template.name)
                    .focused($isNameFocused)
                    .submitLabel(.done)
                    .glassField()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .accessibilityIdentifier("routineName")
            } footer: {
                if template.name.isEmpty {
                    Text("Leave it empty and we'll name it after the muscles, e.g. Chest & Back.").font(.footnote)
                }
            }
            Section {
                WeekdayPicker(selection: Binding(get: { template.weekdays }, set: { env.templates.setDays($0, for: template) }))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } header: {
                Text("Days").font(.body).foregroundStyle(.white).textCase(nil)
            } footer: {
                Text(daysFooter).font(.footnote)
            }
            Section {
                ForEach(template.orderedExercises) { item in
                    TemplateExerciseRow(item: item, onReplace: { replacing = item }, onRemove: { env.templates.removeExercise(item) })
                        .buttonStyle(.borderless)
                        .deleteDisabled(editMode.isEditing)
                        .glassListRow()
                }
                .onDelete { offsets in
                    let items = template.orderedExercises
                    for index in offsets { env.templates.removeExercise(items[index]) }
                }
                .onMove { env.templates.move(in: template, from: $0, to: $1) }
                Button { isPickerPresented = true } label: { GlassAddLabel(title: "Add exercises") }
                    .buttonStyle(.plain)
                    .glassListRow()
                    .accessibilityIdentifier("addRoutineExercises")
            } header: {
                Text("Exercises").font(.body).foregroundStyle(.white).textCase(nil)
            } footer: {
                Text("Tap ⋯ to replace or remove an exercise.").font(.footnote)
            }
        }
        .glassList()
        .navigationTitle(isNew ? "New routine" : "Edit routine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // A pushed screen: Back saves too. While reordering, Done only ends reordering.
            ToolbarItem(placement: .topBarTrailing) {
                if editMode.isEditing {
                    Button("Done") { withAnimation { editMode = .inactive } }
                } else {
                    Button("Reorder") { withAnimation { editMode = .active } }
                }
            }
        }
        .navigationBarBackButtonHidden(editMode.isEditing)
        .environment(\.editMode, $editMode)
        .onAppear { if isNew { isNameFocused = true } }
        .onDisappear(perform: finish)
        .sheet(item: $replacing) { item in
            ExercisePickerView(title: "Replace exercise", allowsMultipleSelection: false) { selected in
                if let exercise = selected.first { env.templates.replaceExercise(item, with: exercise) }
            }
            .environment(env)
        }
        .sheet(isPresented: $isPickerPresented) {
            ExercisePickerView(title: "Add exercises") { selected in
                for exercise in selected { env.templates.addExercise(exercise, to: template) }
            }
            .environment(env)
        }
    }

    /// Days are optional; one routine per day, so picking a taken day moves it here.
    private var daysFooter: String {
        let symbols = Calendar(identifier: .iso8601).shortWeekdaySymbols
        let taken = env.templates.userTemplates()
            .filter { $0.id != template.id && !$0.name.isEmpty }
            .flatMap { other in other.weekdays.map { ($0, other.name) } }
            .sorted { $0.0 < $1.0 }
            .map { String(localized: "\(symbols[$0.0 % 7]) is \($0.1)") }
        let base = String(localized: "Optional. Days show on This week.")
        return taken.isEmpty ? base : base + " " + taken.joined(separator: ", ") + ". " + String(localized: "Picking one of those moves it here.")
    }

    /// Leaving: a new routine without exercises is thrown away; an unnamed one is named after its muscles.
    private func finish() {
        if template.orderedExercises.isEmpty {
            if isNew { env.templates.delete(template) }
        } else if template.name.trimmingCharacters(in: .whitespaces).isEmpty {
            let muscles = template.orderedExercises.compactMap(\.exercise?.primaryMuscle)
            template.name = env.templates.uniqueName(RoutineNaming.name(primaryMuscles: muscles))
        }
        env.templates.save()
        env.dataDidChange()
    }
}

/// One exercise in the workout editor: what it is, ⋯ to replace or remove, then sets, reps and rest.
struct TemplateExerciseRow: View {
    @Environment(\.editMode) private var editMode
    @Bindable var item: TemplateExercise
    let onReplace: () -> Void
    let onRemove: () -> Void

    private static let restOptions = [0, 30, 45, 60, 75, 90, 120, 150, 180, 240, 300]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ExercisePhoto(exercise: item.exercise, width: 56, height: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.exercise?.name ?? "").font(.callout.weight(.medium)).lineLimit(2)
                    if let exercise = item.exercise {
                        Text(exercise.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if editMode?.wrappedValue.isEditing != true { optionsMenu }
            }
            // Reordering shows just the name, so the rows are short enough to drag.
            if editMode?.wrappedValue.isEditing != true { values }
        }
    }

    private var optionsMenu: some View {
        Menu {
            Button("Replace exercise", systemImage: "arrow.left.arrow.right", action: onReplace)
            Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: Theme.minTap, height: Theme.minTap)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Options for \(item.exercise?.name ?? "")")
    }

    private var values: some View {
        HStack(spacing: 8) {
            valueMenu("Sets", value: "\(item.setCount)", selection: $item.setCount, options: Array(1...10)) { "\($0)" }
            if item.exercise?.type != .duration {
                valueMenu("Reps", value: "\(item.targetReps)", selection: $item.targetReps,
                          options: Array(Set(Array(1...30) + [item.targetReps])).sorted()) { "\($0)" }
            }
            valueMenu("Rest", value: Self.rest(item.restSec), selection: $item.restSec,
                      options: Array(Set(Self.restOptions + [item.restSec])).sorted(), label: Self.rest)
        }
    }

    private static func rest(_ seconds: Int) -> String {
        seconds == 0 ? String(localized: "Off") : DurationFormatter.clock(seconds)
    }

    /// Small labelled box; tapping it opens a menu of values.
    private func valueMenu(_ title: LocalizedStringKey, value: String, selection: Binding<Int>, options: [Int], label: @escaping (Int) -> String) -> some View {
        Menu {
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { Text(label($0)).tag($0) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption2).foregroundStyle(.white.opacity(0.6))
                HStack(spacing: 4) {
                    Text(value).font(.subheadline.weight(.medium)).monospacedDigit().foregroundStyle(.white)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(0.08))
                    .strokeBorder(.white.opacity(0.16))
            )
            .contentShape(Rectangle())
        }
        .accessibilityLabel(Text(title) + Text(" \(value)"))
    }
}
