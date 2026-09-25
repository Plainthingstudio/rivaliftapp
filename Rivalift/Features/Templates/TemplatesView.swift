import SwiftUI

/// LIB-04 … LIB-06 / appendix A.8.
struct TemplatesView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var segment: Segment = .mine
    @State private var mine: [WorkoutTemplate] = []
    @State private var programs: [TemplateRepository.Program] = []
    @State private var editing: WorkoutTemplate?
    @State private var toDelete: WorkoutTemplate?

    enum Segment: Hashable { case mine, programs }

    var body: some View {
        List {
            Picker("Templates", selection: $segment) {
                Text("My templates").tag(Segment.mine)
                Text("Programs").tag(Segment.programs)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            switch segment {
            case .mine:
                if mine.isEmpty {
                    Text("Create a template or save a finished workout as one.")
                        .foregroundStyle(.secondary)
                }
                ForEach(mine) { template in
                    TemplateCard(template: template, onEdit: { editing = template }, onDuplicate: {
                        env.templates.duplicate(template)
                        reload()
                    }, onDelete: { toDelete = template })
                }
            case .programs:
                ForEach(programs) { program in
                    Section(program.name) {
                        ForEach(program.templates) { template in
                            TemplateCard(template: template, onEdit: nil, onDuplicate: {
                                env.templates.duplicate(template)
                                segment = .mine
                                reload()
                            }, onDelete: nil)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Templates")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New template", systemImage: "plus") {
                    editing = env.templates.create(name: String(localized: "New template"))
                }
            }
        }
        .sheet(item: $editing, onDismiss: reload) { template in
            TemplateEditorView(template: template).environment(env)
        }
        .confirmationDialog("Delete template?", isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let toDelete { env.templates.delete(toDelete) }
                reload()
            }
        }
        .onAppear {
            reload()
            if mine.isEmpty { segment = .programs }
        }
    }

    private func reload() {
        mine = env.templates.userTemplates()
        // The user's plan first, then the other programs in seed order.
        let all = env.templates.programs()
        programs = all.filter { $0.name == env.settings.planProgram } + all.filter { $0.name != env.settings.planProgram }
    }
}

struct TemplateCard: View {
    @Environment(AppEnvironment.self) private var env
    let template: WorkoutTemplate
    var onEdit: (() -> Void)?
    var onDuplicate: () -> Void
    var onDelete: (() -> Void)?

    var body: some View {
        NavigationLink {
            TemplateDetailView(template: template)
        } label: {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(template.name).font(.headline)
                Spacer()
                Menu {
                    if let onEdit { Button("Edit", systemImage: "pencil", action: onEdit) }
                    Button("Duplicate", systemImage: "plus.square.on.square", action: onDuplicate)
                    if let onDelete { Button("Delete", systemImage: "trash", role: .destructive, action: onDelete) }
                } label: {
                    Image(systemName: "ellipsis").frame(width: Theme.minTap, height: Theme.minTap)
                }
                .accessibilityLabel("Template options")
            }
            Text(template.orderedExercises.compactMap(\.exercise?.name).joined(separator: ", "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text("\(template.totalSets) sets · ~\(template.estimatedDurationMin) min")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// Create and edit a user template: exercises, sets, target reps, rest (LIB-06).
struct TemplateEditorView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Bindable var template: WorkoutTemplate
    @State private var isPickerPresented = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Template name", text: $template.name)
                }
                Section("Exercises") {
                    ForEach(template.orderedExercises) { item in
                        TemplateExerciseRow(item: item)
                    }
                    .onDelete { offsets in
                        let items = template.orderedExercises
                        for index in offsets { env.templates.removeExercise(items[index]) }
                    }
                    .onMove { env.templates.move(in: template, from: $0, to: $1) }
                    Button("Add exercises", systemImage: "plus") { isPickerPresented = true }
                }
            }
            .navigationTitle("Edit template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        env.templates.save()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarLeading) { EditButton() }
            }
            .sheet(isPresented: $isPickerPresented) {
                ExercisePickerView(title: "Add exercises") { selected in
                    for exercise in selected { env.templates.addExercise(exercise, to: template) }
                }
                .environment(env)
            }
        }
    }
}

struct TemplateExerciseRow: View {
    @Bindable var item: TemplateExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.exercise?.name ?? "").font(.headline)
            Stepper("Sets: \(item.setCount)", value: $item.setCount, in: 1...10)
            if item.exercise?.type != .duration {
                Stepper("Target reps: \(item.targetReps)", value: $item.targetReps, in: 1...50)
            }
            Stepper("Rest: \(DurationFormatter.clock(item.restSec))", value: $item.restSec, in: 0...300, step: 15)
        }
        .font(.subheadline)
    }
}
