import SwiftUI

/// Editable mode settings; keeps Strength and Custom edits while switching between modes.
struct LeagueModeDraft: Hashable {
    var kind: LeagueMode.Kind = .consistency
    var strength = StrengthSetup()
    var categories: [CustomCategoryScorer.Category] = SampleLeagues.pullUpClubCategories

    init(_ mode: LeagueMode = .consistency) {
        kind = mode.kind
        switch mode {
        case .consistency: break
        case .strength(let setup): strength = setup
        case .custom(let categories): self.categories = categories
        }
    }

    var mode: LeagueMode {
        switch kind {
        case .consistency: .consistency
        case .strength: .strength(strength)
        case .custom: .custom(categories)
        }
    }

    var isValid: Bool {
        switch kind {
        case .consistency: true
        case .strength: StrengthSetup.liftRange.contains(strength.exerciseKeys.count)
        case .custom: CustomCategoryScorer.categoryRange.contains(categories.count)
        }
    }
}

extension LeagueMode.Kind {
    var title: LocalizedStringKey {
        switch self {
        case .consistency: "Consistency"
        case .strength: "Strength"
        case .custom: "Custom"
        }
    }

    var summary: LocalizedStringKey {
        switch self {
        case .consistency: "Points for showing up, records and streaks. Fair for every level."
        case .strength: "Who gets stronger on 1–5 lifts, measured by estimated 1RM (the most you could lift once)."
        case .custom: "1–5 challenges you pick, like most pull-ups or longest plank. Each has its own ranking."
        }
    }
}

extension CustomCategoryScorer.Metric {
    /// Metrics that make sense for an exercise type.
    static func options(for type: ExerciseType) -> [Self] {
        switch type {
        case .weightReps: [.heaviestWeight, .estimated1RM, .bestSetVolume, .maxReps, .totalReps]
        case .bodyweightReps: [.maxReps, .totalReps]
        case .duration: [.longestHold]
        }
    }

    var usesMinReps: Bool { self == .heaviestWeight || self == .bestSetVolume }

    var explanation: LocalizedStringKey {
        switch self {
        case .maxReps: "Most reps in a single set."
        case .totalReps: "All reps of the week added up."
        case .heaviestWeight: "Heaviest weight lifted for at least the minimum reps."
        case .estimated1RM: "Estimated one-rep max from your best set."
        case .bestSetVolume: "Weight × reps of your best single set, so weight and reps both count."
        case .longestHold: "Longest time held in a single set."
        }
    }

    func example(unit: WeightUnit) -> String {
        func w(_ kg: Double) -> String { WeightFormatter.string(kg: kg, unit: unit, includeUnit: true) }
        return switch self {
        case .maxReps: String(localized: "Sets of 10, 12 and 9 reps → 12 reps")
        case .totalReps: String(localized: "30 + 25 + 20 + 40 reps over the week → 115 reps")
        case .heaviestWeight: String(localized: "Minimum 8 reps: \(w(16)) × 8 counts, \(w(18)) × 5 doesn't → \(w(16))")
        case .estimated1RM: String(localized: "\(w(80)) × 8 reps → about \(w(OneRepMax.epley(weightKg: 80, reps: 8)))")
        case .bestSetVolume: String(localized: "\(w(14)) × 12 = \(w(168)) beats \(w(16)) × 8 = \(w(128))")
        case .longestHold: String(localized: "Holds of 1:20, 2:00 and 1:45 → 2:00")
        }
    }
}

extension CustomCategoryScorer.Comparison {
    var title: LocalizedStringKey { self == .absolute ? "Absolute" : "Improvement" }

    var explanation: LocalizedStringKey {
        self == .absolute
            ? "Best result this week wins. Suits groups at a similar level."
            : "Biggest gain over your own best of the previous 8 weeks wins. Fair for mixed levels."
    }

    var example: LocalizedStringKey {
        self == .absolute
            ? "Gilang 14 pull-ups, Hana 11 → Gilang wins"
            : "Hana's best was 8, this week 11 (+3). Gilang's best was 13, this week 14 (+1) → Hana wins"
    }
}

/// Mode sections for a Form (SOC-12 … SOC-14, SOC-16). Editors push on the containing
/// NavigationStack; a sheet on top of the create/settings sheet would close it.
struct LeagueModeSections: View {
    @Environment(AppEnvironment.self) private var env
    @Binding var draft: LeagueModeDraft

    var body: some View {
        Section {
            Picker("League", selection: $draft.kind) {
                ForEach(LeagueMode.Kind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("leagueModePicker")
        } header: {
            Text("League")
        } footer: {
            Text(draft.kind.summary)
        }

        switch draft.kind {
        case .consistency:
            EmptyView()
        case .strength:
            strengthSections
        case .custom:
            customSections
        }
    }

    @ViewBuilder
    private var strengthSections: some View {
        Section {
            ForEach(draft.strength.exerciseKeys, id: \.self) { key in
                Text(env.exercises.exercise(key: key)?.name ?? key)
            }
            .onDelete { offsets in
                guard draft.strength.exerciseKeys.count - offsets.count >= StrengthSetup.liftRange.lowerBound else { return }
                draft.strength.exerciseKeys.remove(atOffsets: offsets)
            }
            if draft.strength.exerciseKeys.count < StrengthSetup.liftRange.upperBound {
                NavigationLink {
                    LeagueExercisePicker(title: "Add lift", allowedTypes: [.weightReps], excluding: draft.strength.exerciseKeys) {
                        draft.strength.exerciseKeys.append($0.key)
                    }
                } label: {
                    Label("Add lift", systemImage: "plus").foregroundStyle(Theme.accent)
                }
                .accessibilityIdentifier("addLiftButton")
            } else {
                Label("Add lift · \(StrengthSetup.liftRange.upperBound) is the maximum", systemImage: "plus")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Lifts")
        } footer: {
            Text("Any built-in exercise with weights, for example Overhead Press or Barbell Row. Up to \(StrengthSetup.liftRange.upperBound); swipe to remove.")
        }
        Section {
            Button {
                mixIntoCustom()
            } label: {
                Label("Mix lifts with other exercises", systemImage: "square.stack.3d.up")
            }
            .accessibilityIdentifier("mixIntoCustomButton")
        } footer: {
            Text("Strength compares estimated 1RM, so it needs weights. To add pull-ups, push-ups or planks, this switches to Custom and keeps your lifts as 1RM categories.")
        }
        Section {
            Picker("Compare", selection: $draft.strength.comparison) {
                Text("Relative").tag(StrengthScorer.Comparison.relative)
                Text("Absolute").tag(StrengthScorer.Comparison.absolute)
            }
            .pickerStyle(.segmented)
            StrengthExample(comparison: draft.strength.comparison)
        } header: {
            Text("How to compare")
        }
    }

    /// Strength lifts become "Estimated 1RM" categories (Improvement for Relative) so
    /// other exercises can join them in a Custom league.
    private func mixIntoCustom() {
        let comparison: CustomCategoryScorer.Comparison = draft.strength.comparison == .relative ? .improvement : .absolute
        draft.categories = draft.strength.exerciseKeys.prefix(CustomCategoryScorer.categoryRange.upperBound).map {
            CustomCategoryScorer.Category(id: UUID().uuidString, exerciseKey: $0, metric: .estimated1RM, comparison: comparison, minReps: nil)
        }
        draft.kind = .custom
    }

    @ViewBuilder
    private var customSections: some View {
        Section {
            ForEach(Array(draft.categories.enumerated()), id: \.element.id) { index, category in
                NavigationLink {
                    CategoryEditorView(category: category) { draft.categories[index] = $0 }
                } label: {
                    CategoryLabel(category: category)
                }
            }
            .onDelete { offsets in
                guard draft.categories.count - offsets.count >= CustomCategoryScorer.categoryRange.lowerBound else { return }
                draft.categories.remove(atOffsets: offsets)
            }
            if draft.categories.count < CustomCategoryScorer.categoryRange.upperBound {
                NavigationLink {
                    CategoryEditorView(category: nil) { draft.categories.append($0) }
                } label: {
                    Label("New category", systemImage: "plus").foregroundStyle(Theme.accent)
                }
                .accessibilityIdentifier("newCategoryButton")
            } else {
                Label("New category · \(CustomCategoryScorer.categoryRange.upperBound) is the maximum", systemImage: "plus")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Categories")
        } footer: {
            Text("Each category is one exercise and what counts, like \"Pull-Up · Max reps\". Tap to change, swipe to remove. Everyone is ranked per category and the Overall tab adds up the places.")
        }
        let unused = CustomCategoryScorer.presets.filter { preset in
            !draft.categories.contains { $0.exerciseKey == preset.exerciseKey && $0.metric == preset.metric }
        }
        if !unused.isEmpty && draft.categories.count < CustomCategoryScorer.categoryRange.upperBound {
            Section("Popular") {
                ForEach(unused, id: \.id) { preset in
                    Button {
                        draft.categories.append(preset)
                    } label: {
                        HStack {
                            CategoryLabel(category: preset)
                            Spacer()
                            Image(systemName: "plus.circle.fill").foregroundStyle(Theme.accent)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Add \(env.exercises.exercise(key: preset.exerciseKey)?.name ?? preset.exerciseKey), \(CategorySummary.text(preset))"))
                }
            }
        }
    }
}

private struct CategoryLabel: View {
    @Environment(AppEnvironment.self) private var env
    let category: CustomCategoryScorer.Category

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(env.exercises.exercise(key: category.exerciseKey)?.name ?? category.exerciseKey).foregroundStyle(.primary)
            Text(CategorySummary.text(category))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

enum CategorySummary {
    /// "Best set volume · Absolute · min 8 reps".
    static func text(_ category: CustomCategoryScorer.Category) -> String {
        var parts = [category.metric.displayName]
        parts.append(category.comparison == .absolute ? String(localized: "Absolute") : String(localized: "Improvement"))
        if let minReps = category.minReps, category.metric.usesMinReps { parts.append(String(localized: "min \(minReps) reps")) }
        return parts.joined(separator: " · ")
    }
}

/// Andi (strong) vs Sam (beginner) on the same three lifts, to show what Relative and
/// Absolute reward.
struct StrengthExample: View {
    @Environment(AppEnvironment.self) private var env
    let comparison: StrengthScorer.Comparison

    private struct Lifter {
        var name: String
        var lifts: [(from: Double, to: Double)]
    }

    private let andi = Lifter(name: "Andi", lifts: [(100, 103), (120, 126), (150, 153)])
    private let sam = Lifter(name: "Sam", lifts: [(40, 44), (50, 55), (60, 63)])

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Example").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            row(andi, tag: String(localized: "strong lifter"))
            row(sam, tag: String(localized: "beginner"))
            Text(comparison == .relative
                 ? "Sam wins: a bigger gain for their own level, even with lighter weights."
                 : "Andi wins: the heaviest total. Best when everyone is at a similar level.")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accent)
        }
        .padding(.vertical, 4)
    }

    private func row(_ lifter: Lifter, tag: String) -> some View {
        let gains = lifter.lifts.map { ($0.to - $0.from) / $0.from }
        let average = gains.reduce(0, +) / Double(gains.count)
        let total = lifter.lifts.reduce(0) { $0 + $1.to }
        let detail = comparison == .relative
            ? gains.map { $0.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always())) }.joined(separator: " · ")
            : lifter.lifts.map { WeightFormatter.string(kg: $0.to, unit: env.unit) }.joined(separator: " + ")
        let score = comparison == .relative
            ? average.formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always()))
            : WeightFormatter.string(kg: total, unit: env.unit, includeUnit: true)
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(lifter.name) (\(tag))").font(.subheadline.weight(.semibold))
                Text(comparison == .relative ? String(localized: "Squat, bench, deadlift gains: \(detail)") : String(localized: "Best 1RM: \(detail)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(score).font(.subheadline.weight(.bold)).monospacedDigit()
        }
    }
}

/// Built-in exercises that fit a league, pushed on the current NavigationStack.
struct LeagueExercisePicker: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    let title: LocalizedStringKey
    let allowedTypes: Set<ExerciseType>
    var excluding: [String] = []
    var onPick: (Exercise) -> Void
    @State private var query = ""

    var body: some View {
        let results = env.exercises.search(query, muscles: [], equipment: [])
            .filter { !$0.isCustom && allowedTypes.contains($0.type) && !excluding.contains($0.key) }
        List(results) { exercise in
            Button {
                onPick(exercise)
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    ExerciseIcon(muscle: exercise.primaryMuscle, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name).foregroundStyle(.primary)
                        Text(exercise.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .listRowBackground(Theme.listRow)
        }
        .screenBackground()
        .overlay {
            if results.isEmpty { ContentUnavailableView.search(text: query) }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search exercises")
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One Custom category: exercise, what counts, how to compare, minimum reps (SOC-14).
struct CategoryEditorView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    let category: CustomCategoryScorer.Category?
    var onSave: (CustomCategoryScorer.Category) -> Void

    @State private var exerciseKey: String?
    @State private var metric: CustomCategoryScorer.Metric = .maxReps
    @State private var comparison: CustomCategoryScorer.Comparison = .absolute
    @State private var minReps = 8

    init(category: CustomCategoryScorer.Category?, onSave: @escaping (CustomCategoryScorer.Category) -> Void) {
        self.category = category
        self.onSave = onSave
        _exerciseKey = State(initialValue: category?.exerciseKey)
        _metric = State(initialValue: category?.metric ?? .maxReps)
        _comparison = State(initialValue: category?.comparison ?? .absolute)
        _minReps = State(initialValue: category?.minReps ?? 8)
    }

    var body: some View {
        let exercise = exerciseKey.flatMap { env.exercises.exercise(key: $0) }
        Form {
            Group {
                Section {
                    NavigationLink {
                        LeagueExercisePicker(title: "Choose exercise", allowedTypes: Set(ExerciseType.allCases)) { picked in
                            exerciseKey = picked.key
                            let options = CustomCategoryScorer.Metric.options(for: picked.type)
                            if !options.contains(metric) { metric = options[0] }
                        }
                    } label: {
                        LabeledContent("Exercise") {
                            Text(exercise?.name ?? String(localized: "Choose"))
                                .foregroundStyle(exercise == nil ? Theme.accent : .secondary)
                        }
                    }
                    .accessibilityIdentifier("categoryExerciseRow")
                } footer: {
                    Text("Built-in exercises only, so everyone logs the same one.")
                }

                if let exercise {
                    Section("What counts") {
                        ForEach(CustomCategoryScorer.Metric.options(for: exercise.type), id: \.self) { option in
                            choiceRow(isSelected: option == metric) {
                                metric = option
                            } title: {
                                Text(option.displayName)
                            } detail: {
                                Text(option.explanation)
                            }
                        }
                        if metric.usesMinReps {
                            Stepper("Minimum reps: \(minReps)", value: $minReps, in: 1...30)
                        }
                        Label(metric.example(unit: env.unit), systemImage: "lightbulb")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Section("How to compare") {
                        ForEach([CustomCategoryScorer.Comparison.absolute, .improvement], id: \.self) { option in
                            choiceRow(isSelected: option == comparison) {
                                comparison = option
                            } title: {
                                Text(option.title)
                            } detail: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(option.explanation)
                                    Text(option.example).italic()
                                }
                            }
                        }
                    }
                }
            }
            .listRowBackground(Theme.listRow)
        }
        .screenBackground()
        .navigationTitle(category == nil ? "New category" : "Edit category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(category == nil ? "Add" : "Save") {
                    guard let exerciseKey else { return }
                    onSave(CustomCategoryScorer.Category(
                        id: category?.id ?? UUID().uuidString,
                        exerciseKey: exerciseKey,
                        metric: metric,
                        comparison: comparison,
                        minReps: metric.usesMinReps ? minReps : nil
                    ))
                    dismiss()
                }
                .disabled(exerciseKey == nil)
                .accessibilityIdentifier("saveCategoryButton")
            }
        }
    }

    private func choiceRow<Title: View, Detail: View>(
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder title: () -> Title,
        @ViewBuilder detail: () -> Detail
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Theme.accent : Color.secondary)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    title().font(.body.weight(isSelected ? .semibold : .regular)).foregroundStyle(.primary)
                    detail().font(.caption).foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Group settings: change the league mode, effective next Monday (SOC-12).
struct GroupSettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    let group: LeagueGroup
    @State private var draft: LeagueModeDraft

    init(group: LeagueGroup) {
        self.group = group
        _draft = State(initialValue: LeagueModeDraft(group.pendingMode ?? group.mode))
    }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section {
                        HStack(spacing: 12) {
                            GroupEmoji(emoji: group.emoji, size: 44)
                            VStack(alignment: .leading) {
                                Text(group.name).font(.headline)
                                Text("Code \(group.inviteCode) · \(group.memberCount) members").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    LeagueModeSections(draft: $draft)
                    Section {
                        Text("Changes start next Monday. This week stays \(group.mode.displayName) so nobody loses points mid-week.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Theme.listRow)
            }
            .screenBackground()
            .navigationTitle("Group settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        env.leagues.scheduleMode(draft.mode, for: group.id)
                        dismiss()
                    }
                    .disabled(!draft.isValid)
                }
            }
        }
    }
}

/// How the group's league scores, in plain words (appendix A.10).
struct LeagueModeExplainer: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    let mode: LeagueMode

    var body: some View {
        switch mode {
        case .consistency:
            ScoringExplainerView()
        case .strength(let setup):
            explainer(title: "Strength league") {
                Section {
                    Text(setup.comparison == .relative
                         ? "Your score is the average % gain in estimated 1RM on the group's lifts, compared with your own best of the previous 8 weeks."
                         : "Your score is the total of your best estimated 1RM on the group's lifts this week.")
                    HStack {
                        Text("What is estimated 1RM?")
                        Spacer()
                        OneRepMaxInfoButton(unit: env.unit)
                    }
                    StrengthExample(comparison: setup.comparison)
                }
                Section("Lifts") {
                    ForEach(setup.exerciseKeys, id: \.self) { Text(env.exercises.exercise(key: $0)?.name ?? $0) }
                }
                Section("Fair play") {
                    Text("Only working sets of 1–12 reps count.")
                    if setup.comparison == .relative {
                        Text("A lift without 8 weeks of history is a baseline week and counts from next week.")
                        Text("A drop below your baseline counts as 0, never negative.")
                    }
                    Text("Jumps of more than 25% over your previous best are saved to your log but don't count here.")
                }
            }
        case .custom(let categories):
            explainer(title: "Custom league") {
                Section {
                    Text("Every category has its own ranking. With 4 people who logged it, 1st place earns 4 points, 2nd earns 3, 3rd earns 2 and 4th earns 1. No entry earns 0.")
                    Text("The Overall tab adds up those points. A tie goes to whoever won more categories, then to the first category.")
                }
                Section("Categories") {
                    ForEach(categories, id: \.id) { category in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(env.exercises.exercise(key: category.exerciseKey)?.name ?? category.exerciseKey)
                            Text(CategorySummary.text(category)).font(.caption).foregroundStyle(.secondary)
                            Text(category.metric.explanation).font(.caption)
                            Text(category.metric.example(unit: env.unit)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Fair play") {
                    Text("Only the built-in exercise counts, not a custom one with the same name.")
                    Text("Jumps of more than 25% (weight) or 50% (reps, time) over your previous best don't count here.")
                }
            }
        }
    }

    private func explainer<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            List { Group { content() }.listRowBackground(Theme.listRow) }
            .screenBackground()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
        }
    }
}
