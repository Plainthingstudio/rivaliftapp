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
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PillPicker(selection: $segment, options: [(.mine, "My templates"), (.programs, "Programs")])
                    .frame(maxWidth: .infinity)
                switch segment {
                case .mine:
                    if mine.isEmpty {
                        Text("Create a template or save a finished workout as one.")
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
        .navigationTitle("Templates")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New template", systemImage: "plus") {
                    editing = env.templates.create(name: String(localized: "New template"))
                }
                .tint(.white)
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
    @Environment(\.dismiss) private var dismiss
    @Bindable var template: WorkoutTemplate
    @State private var isPickerPresented = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Template name", text: $template.name)
                        .glassField()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                Section {
                    ForEach(template.orderedExercises) { item in
                        TemplateExerciseRow(item: item).glassListRow()
                    }
                    .onDelete { offsets in
                        let items = template.orderedExercises
                        for index in offsets { env.templates.removeExercise(items[index]) }
                    }
                    .onMove { env.templates.move(in: template, from: $0, to: $1) }
                    Button { isPickerPresented = true } label: { GlassAddLabel(title: "Add exercises") }
                        .buttonStyle(.plain)
                        .glassListRow()
                } header: {
                    Text("Exercises").font(.body).foregroundStyle(.white).textCase(nil)
                } footer: {
                    Text("Swipe left to remove, tap Edit to reorder.").font(.footnote)
                }
            }
            .glassList()
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
            HStack(spacing: 12) {
                ExercisePhoto(exercise: item.exercise, width: 52, height: 38)
                Text(item.exercise?.name ?? "").font(.headline)
            }
            Stepper("Sets: \(item.setCount)", value: $item.setCount, in: 1...10)
            if item.exercise?.type != .duration {
                Stepper("Target reps: \(item.targetReps)", value: $item.targetReps, in: 1...50)
            }
            Stepper("Rest: \(DurationFormatter.clock(item.restSec))", value: $item.restSec, in: 0...300, step: 15)
        }
        .font(.subheadline)
    }
}
