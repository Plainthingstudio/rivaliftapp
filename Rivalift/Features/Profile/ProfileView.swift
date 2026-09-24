import Charts
import SwiftUI

/// AUTH-04 / appendix A.12.
struct ProfileView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var sessions: [WorkoutSession] = []
    @State private var isEditPresented = false

    struct WeekBar: Identifiable {
        var week: Date
        var minutes: Int
        var id: Date { week }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    AvatarView(name: displayName, size: 64)
                    VStack(alignment: .leading) {
                        Text(displayName).font(.title2.bold())
                        Button("Edit profile") { isEditPresented = true }
                            .font(.subheadline)
                    }
                }
                .padding(.vertical, 4)
            }
            Section {
                Grid(horizontalSpacing: 12) {
                    GridRow {
                        StatTile(value: "\(sessions.count)", label: "Workouts")
                        StatTile(value: WeightFormatter.volume(kg: sessions.reduce(0) { $0 + $1.totalVolumeKg }, unit: env.unit), label: "Total volume")
                        StatTile(value: "\(longestStreak)", label: "Best streak (wk)")
                    }
                }
            }
            Section("Last 8 weeks") {
                Chart(weekBars) { bar in
                    BarMark(x: .value("Week", bar.week, unit: .weekOfYear), y: .value("Minutes", bar.minutes))
                        .foregroundStyle(Theme.accent)
                }
                .frame(height: 160)
                .accessibilityLabel("Training minutes per week")
            }
            Section {
                NavigationLink { TemplatesView() } label: { Label("Templates", systemImage: "list.bullet.rectangle") }
                NavigationLink { ExerciseLibraryView() } label: { Label("Exercises", systemImage: "dumbbell") }
                NavigationLink { SettingsView() } label: { Label("Settings", systemImage: "gearshape") }
            }
        }
        .navigationTitle("Profile")
        .onAppear(perform: reload)
        .onChange(of: env.dataVersion) { _, _ in reload() }
        .sheet(isPresented: $isEditPresented) { EditProfileView().environment(env) }
    }

    private var displayName: String {
        env.settings.displayName.isEmpty ? String(localized: "Lifter") : env.settings.displayName
    }

    private var weekBars: [WeekBar] {
        let calendar = WeekCalendar()
        let current = calendar.weekStart(for: Date())
        return (0..<8).reversed().compactMap { offset -> WeekBar? in
            guard let week = calendar.calendar.date(byAdding: .weekOfYear, value: -offset, to: current) else { return nil }
            let end = calendar.weekEnd(for: week)
            let minutes = sessions.filter { $0.startedAt >= week && $0.startedAt < end }.reduce(0) { $0 + $1.durationSec / 60 }
            return WeekBar(week: week, minutes: minutes)
        }
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

struct EditProfileView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        AvatarView(name: name.isEmpty ? "?" : name, size: 80)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
                Section {
                    TextField("Display name", text: $name)
                        .textInputAutocapitalization(.words)
                        .onChange(of: name) { _, value in
                            if value.count > 30 { name = String(value.prefix(30)) }
                        }
                } footer: {
                    Text("Shown to friends in your leagues. Up to 30 characters.")
                }
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        env.settings.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        env.saveSettings()
                        dismiss()
                    }
                }
            }
        }
        .onAppear { name = env.settings.displayName }
    }
}

/// Browse the library, create and delete custom exercises.
struct ExerciseLibraryView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var query = ""
    @State private var exercises: [Exercise] = []
    @State private var isCreatePresented = false

    var body: some View {
        List(exercises) { exercise in
            NavigationLink {
                ExerciseDetailView(exercise: exercise)
            } label: {
                HStack(spacing: 12) {
                    ExerciseIcon(muscle: exercise.primaryMuscle, size: 36)
                    VStack(alignment: .leading) {
                        Text(exercise.name)
                        Text(exercise.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .swipeActions {
                if exercise.isCustom {
                    Button("Delete", role: .destructive) {
                        env.exercises.deleteCustom(exercise)
                        reload()
                    }
                }
            }
        }
        .searchable(text: $query)
        .navigationTitle("Exercises")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Create", systemImage: "plus") { isCreatePresented = true }
            }
        }
        .sheet(isPresented: $isCreatePresented, onDismiss: reload) {
            CreateExerciseView { _ in }.environment(env)
        }
        .onAppear(perform: reload)
        .onChange(of: query) { _, _ in reload() }
    }

    private func reload() {
        exercises = env.exercises.search(query, muscles: [], equipment: [])
    }
}
