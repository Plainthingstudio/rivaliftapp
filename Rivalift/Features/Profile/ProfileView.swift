import PhotosUI
import SwiftUI

/// AUTH-04 / appendix A.12. Layout follows Figma "Profile" (node 163:44596).
struct ProfileView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var sessions: [WorkoutSession] = []
    @State private var isEditPresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenTitle(title: "Profile")
                header
                historyCard
                ProgressCard(sessions: sessions, unit: env.unit)
                menu
            }
            .padding()
        }
        .screenBackground()
        .navigationTitle("Profile")
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: reload)
        .onChange(of: env.dataVersion) { _, _ in reload() }
        .sheet(isPresented: $isEditPresented) { EditProfileView().environment(env) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 24) {
                ProfileAvatar(data: env.settings.avatarImageData, size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName).font(.body.weight(.medium)).lineLimit(1)
                    Button { isEditPresented = true } label: {
                        HStack(spacing: 0) {
                            Text("Edit Profile")
                            Image("Icon_editchev").accessibilityHidden(true)
                        }
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.2), in: Capsule())
                        .frame(minHeight: Theme.minTap)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, -10)
                }
                Spacer(minLength: 0)
            }
            StatStrip(items: [
                ("\(sessions.count)", sessions.count == 1 ? "Workout" : "Workouts"),
                (WeightFormatter.volume(kg: sessions.reduce(0) { $0 + $1.totalVolumeKg }, unit: env.unit), "Total Volume"),
                ("\(longestStreak)", "Best streak"),
            ])
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var menu: some View {
        VStack(spacing: 12) {
            menuRow("Icon_menu_settings", "Settings", "Account, preference and more.", iconSize: 16) { SettingsView() }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .glassCard()
    }

    /// History moved here from its own tab: this month's count and the latest workout.
    private var historyCard: some View {
        let calendar = Calendar.current
        let thisMonth = sessions.filter { calendar.isDate($0.startedAt, equalTo: Date(), toGranularity: .month) }.count
        return NavigationLink { HistoryView() } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("History").font(.headline.weight(.medium))
                        Text("^[\(thisMonth) workout](inflect: true) in \(Date().formatted(.dateTime.month(.wide)))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 2) {
                        Text("See all")
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                if let last = sessions.first {
                    RecentWorkoutRow(session: last, unit: env.unit)
                } else {
                    Text("Your finished workouts show up here.").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("profileHistory")
    }

    private func menuRow(_ icon: String, _ title: LocalizedStringKey, _ subtitle: LocalizedStringKey, iconSize: CGFloat = 18, @ViewBuilder destination: () -> some View) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 8) {
                RingIcon(image: icon, iconSize: iconSize)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.callout)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                Image("IconChevronCircle").accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var displayName: String {
        env.settings.displayName.isEmpty ? String(localized: "Lifter") : env.settings.displayName
    }

    private var longestStreak: Int {
        let calendar = WeekCalendar()
        let target = env.settings.weeklyTarget
        var perWeek: [Date: Int] = [:]
        for session in sessions { perWeek[calendar.weekStart(for: session.startedAt), default: 0] += 1 }
        let weeks = perWeek.filter { $0.value >= target }.keys.sorted()
        var best = 0, current = 0
        var previous: Date?
        for week in weeks {
            if let previous, calendar.calendar.date(byAdding: .weekOfYear, value: 1, to: previous) == week {
                current += 1
            } else {
                current = 1
            }
            best = max(best, current)
            previous = week
        }
        return best
    }

    private func reload() {
        sessions = env.sessions.completedSessions()
    }
}

/// "Your progress": weekly volume for the chosen range and the change against the range before it.
struct ProgressCard: View {
    let sessions: [WorkoutSession]
    let unit: WeightUnit
    @State private var weeks = 8

    private struct Week: Identifiable {
        var start: Date
        var volume: Double
        var id: Date { start }
    }

    /// The last `count` weeks ending with this one, then the `count` weeks before them.
    private func volumes(count: Int, endingWeeksAgo offset: Int) -> [Week] {
        let calendar = WeekCalendar()
        let current = calendar.weekStart(for: Date())
        return (0..<count).reversed().compactMap { back in
            guard let start = calendar.calendar.date(byAdding: .weekOfYear, value: -(back + offset), to: current) else { return nil }
            let end = calendar.weekEnd(for: start)
            let kg = sessions.filter { $0.startedAt >= start && $0.startedAt < end }.reduce(0) { $0 + $1.totalVolumeKg }
            return Week(start: start, volume: UnitConverter.fromKg(kg, to: unit))
        }
    }

    var body: some View {
        let shown = volumes(count: weeks, endingWeeksAgo: 0)
        let before = volumes(count: weeks, endingWeeksAgo: weeks)
        let total = shown.reduce(0) { $0 + $1.volume }
        let change = TrainingStats.percentChange(current: total, previous: before.reduce(0) { $0 + $1.volume })
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your progress")
                Spacer()
                Menu {
                    Picker("Range", selection: $weeks) {
                        ForEach([4, 8, 12], id: \.self) { Text("Last \($0) weeks").tag($0) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Last \(weeks) weeks")
                        Image("Icon_dropchev").rotationEffect(.degrees(90))
                    }
                    .font(.caption)
                    .foregroundStyle(.white)
                    .frame(minHeight: Theme.minTap)
                }
                .padding(.vertical, -12)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Total Volume").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Text("\(total.formatted(.number.precision(.fractionLength(0)))) \(unit.symbol)").font(.title2)
                    if let change {
                        HStack(spacing: 2) {
                            Image("Icon_trend")
                            Text("\(change > 0 ? "+" : "")\(change)%")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(LinearGradient(
                                    colors: [Color(red: 0xED / 255, green: 1, blue: 0xBC / 255), Color(red: 0xCB / 255, green: 0xF9 / 255, blue: 0x4C / 255), Color(red: 0x8F / 255, green: 0xF1 / 255, blue: 0x83 / 255)],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(change) percent compared with the previous \(weeks) weeks")
                    }
                }
                Text("vs previous \(weeks) weeks").font(.caption).foregroundStyle(.secondary)
            }
            WeeklyVolumeChart(values: shown.map(\.volume), dates: shown.map(\.start))
                .frame(height: 162)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 50)
    }
}

/// Bars with a 0–max axis on the left and week dates underneath (Figma "Charts").
private struct WeeklyVolumeChart: View {
    let values: [Double]
    let dates: [Date]

    /// Round step so the axis reads 0, s, 2s, 3s with 3s at or above the highest bar.
    private var step: Double {
        let raw = max(values.max() ?? 0, 1) / 3
        let magnitude = pow(10, floor(log10(raw)))
        let nice = [1, 2, 2.5, 5, 10].first { $0 * magnitude >= raw } ?? 10
        return nice * magnitude
    }

    var body: some View {
        let top = step * 3
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach((0...3).reversed(), id: \.self) { tick in
                        Text((step * Double(tick)).formatted(.number.notation(.compactName)))
                            .frame(maxHeight: .infinity, alignment: tick == 0 ? .bottom : .top)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 26)
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { _ in
                            Line().stroke(.white.opacity(0.15), style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                                .frame(height: 0.5)
                            Spacer(minLength: 0)
                        }
                    }
                    HStack(alignment: .bottom, spacing: values.count > 8 ? 6 : 12) {
                        ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                            GeometryReader { geo in
                                let height = value > 0 ? max(10, geo.size.height * value / top) : 10
                                VStack(spacing: 0) {
                                    Spacer(minLength: 0)
                                    bar(empty: value <= 0).frame(height: height)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            HStack(spacing: values.count > 8 ? 6 : 12) {
                Color.clear.frame(width: 26, height: 0)
                ForEach(Array(dates.enumerated()), id: \.offset) { index, date in
                    Text(date, format: .dateTime.day(.twoDigits).month(.twoDigits))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity)
                        .opacity(values.count > 8 && index % 2 == 1 ? 0 : 1)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weekly volume chart")
    }

    @ViewBuilder
    private func bar(empty: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        if empty {
            shape.fill(Color(red: 9 / 255, green: 9 / 255, blue: 15 / 255).opacity(0.1)
                .shadow(.inner(color: .white.opacity(0.25), radius: 2.5, y: 1)))
        } else {
            shape.fill(Theme.primaryGradient)
                .overlay(shape.strokeBorder(.white.opacity(0.25), lineWidth: 1))
        }
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { $0.move(to: .zero); $0.addLine(to: CGPoint(x: rect.width, y: 0)) }
        }
    }
}

/// The user's photo, or the default dummy photo when none is set.
struct ProfileAvatar: View {
    var data: Data?
    var size: CGFloat

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable()
            } else {
                Image("ProfilePhoto").resizable()
            }
        }
        .scaledToFill()
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

struct EditProfileView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var photoData: Data?
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(spacing: 12) {
                        ProfileAvatar(data: photoData, size: 96)
                        HStack(spacing: 16) {
                            PhotosPicker(photoData == nil ? "Choose photo" : "Change photo", selection: $photoItem, matching: .images)
                            if photoData != nil {
                                Button("Remove", role: .destructive) { photoData = nil }
                            }
                        }
                        .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    GlassSection("Display name", footer: Text("Shown to friends in your leagues. Up to 30 characters.")) {
                        TextField("Display name", text: $name)
                            .textInputAutocapitalization(.words)
                            .glassField()
                            .onChange(of: name) { _, value in
                                if value.count > 30 { name = String(value.prefix(30)) }
                            }
                    }
                }
                .padding()
            }
            .screenBackground()
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        env.settings.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        env.settings.avatarImageData = photoData
                        env.saveSettings()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            name = env.settings.displayName
            photoData = env.settings.avatarImageData
        }
        .onChange(of: photoItem) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
                photoData = Self.downscaled(data)
            }
        }
    }

    /// Longest side 400 px as JPEG keeps the iCloud record small.
    private static func downscaled(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, 400 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format)
            .image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            .jpegData(compressionQuality: 0.8)
    }
}

/// Browse the library, create and delete custom exercises (Figma "Exercises"): muscle
/// filter chips, then the exercises grouped by first letter.
struct ExerciseLibraryView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var query = ""
    @State private var filter: MuscleFilter = .all
    @State private var exercises: [Exercise] = []
    @State private var isCreatePresented = false

    enum MuscleFilter: String, CaseIterable, Identifiable {
        case all = "All", chest = "Chest", back = "Back", shoulders = "Shoulders", legs = "Legs", arms = "Arms", core = "Core"
        var id: String { rawValue }

        var muscles: [MuscleGroup] {
            switch self {
            case .all: []
            case .chest: [.chest]
            case .back: [.back, .traps]
            case .shoulders: [.shoulders]
            case .legs: [.quads, .hamstrings, .glutes, .calves]
            case .arms: [.biceps, .triceps, .forearms]
            case .core: [.core]
            }
        }
    }

    private var sections: [(letter: String, items: [Exercise])] {
        let grouped = Dictionary(grouping: exercises) { String($0.name.prefix(1)).uppercased() }
        return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8, pinnedViews: []) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MuscleFilter.allCases) { option in
                            let selected = option == filter
                            Button { filter = option } label: {
                                FilterPill(title: String(localized: String.LocalizationValue(option.rawValue)), isSelected: selected)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                }
                .padding(.bottom, 4)
                if exercises.isEmpty {
                    Text("No exercises found").font(.subheadline).foregroundStyle(.secondary).padding(.horizontal, 8)
                }
                ForEach(sections, id: \.letter) { section in
                    Text(section.letter).padding(.horizontal, 8).padding(.top, 10)
                    ForEach(section.items) { exercise in
                        NavigationLink {
                            ExerciseDetailView(exercise: exercise)
                        } label: {
                            ExerciseRowCard(exercise: exercise)
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
                }
            }
            .padding()
        }
        .screenBackground()
        .searchable(text: $query)
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Create", systemImage: "plus") { isCreatePresented = true }
                    .tint(.white)
            }
        }
        .sheet(isPresented: $isCreatePresented, onDismiss: reload) {
            CreateExerciseView { _ in }.environment(env)
        }
        .onAppear(perform: reload)
        .onChange(of: query) { _, _ in reload() }
        .onChange(of: filter) { _, _ in reload() }
    }

    private func reload() {
        exercises = env.exercises.search(query, muscles: Set(filter.muscles), equipment: [])
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

/// Figma "Exercises / Card": photo, name, muscle and equipment, then a chevron, or a
/// check ring when the card is used to pick exercises.
struct ExerciseRowCard: View {
    let exercise: Exercise
    var isSelected: Bool?

    var body: some View {
        HStack(spacing: 24) {
            ExercisePhoto(exercise: exercise)
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name).lineLimit(2)
                DividedText(parts: [exercise.primaryMuscle.displayName, exercise.equipment.displayName])
            }
            Spacer(minLength: 0)
            if let isSelected {
                Image(isSelected ? "Icon_ob_check" : "Icon_ob_uncheck")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
            } else {
                Image("IconChevronCircle").accessibilityHidden(true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected == true ? .isSelected : [])
    }
}
