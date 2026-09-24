import SwiftUI
import UserNotifications

/// SET-01 … SET-06 / appendix A.12.
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var iCloudAvailable = true

    private let restOptions = Array(stride(from: 30, through: 300, by: 15))

    var body: some View {
        @Bindable var settings = env.settings
        Form {
            if !iCloudAvailable {
                Section {
                    Label("iCloud is off. Your workouts are only stored on this iPhone. Turn on iCloud or export your data regularly.", systemImage: "exclamationmark.icloud")
                        .font(.subheadline)
                }
            }

            Section("Units") {
                Picker("Weight unit", selection: $settings.unitRaw) {
                    Text("Kilograms (kg)").tag(WeightUnit.kg.rawValue)
                    Text("Pounds (lb)").tag(WeightUnit.lb.rawValue)
                }
            }

            Section("Training") {
                Stepper(value: Binding(get: { settings.pendingWeeklyTarget ?? settings.weeklyTarget }, set: setWeeklyTarget), in: 1...7) {
                    LabeledContent("Weekly target", value: "\(settings.pendingWeeklyTarget ?? settings.weeklyTarget)")
                }
                if settings.pendingWeeklyTarget != nil {
                    Text("Your new target starts next Monday.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Rest timer") {
                Picker("Compound exercises", selection: $settings.compoundRestSec) {
                    ForEach(restOptions, id: \.self) { Text(DurationFormatter.clock($0)).tag($0) }
                }
                Picker("Isolation exercises", selection: $settings.isolationRestSec) {
                    ForEach(restOptions, id: \.self) { Text(DurationFormatter.clock($0)).tag($0) }
                }
                Toggle("Sound", isOn: $settings.restSoundEnabled)
                Toggle("Vibration", isOn: $settings.restHapticsEnabled)
            }

            Section {
                if notificationStatus == .denied {
                    Label("Notifications are off for Rivalift. The rest timer only works while the app is open. Enable them in iOS Settings.", systemImage: "bell.slash")
                        .font(.subheadline)
                    Button("Open iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
                Toggle("Rest timer finished", isOn: $settings.notifyRestTimer)
                Toggle("Workout reminders", isOn: $settings.notifyWorkoutReminder)
                Toggle("Overtaken in a league", isOn: $settings.notifyOvertaken)
                Toggle("Close to ranking up", isOn: $settings.notifyAlmostRankUp)
                Toggle("League results", isOn: $settings.notifyLeagueResults)
                Toggle("New group members", isOn: $settings.notifyNewMember)
            } header: {
                Text("Notifications")
            }

            Section("Data") {
                Button("Export workouts (CSV)", systemImage: "square.and.arrow.up") { export() }
                if let exportURL {
                    ShareLink("Share export", item: exportURL)
                }
            }

            Section("Account") {
                Text("Sign in with Apple arrives with leagues. Everything works without an account.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                Link("Privacy policy", destination: URL(string: "https://rivalift.app/privacy")!)
                Link("Terms of service", destination: URL(string: "https://rivalift.app/terms")!)
                Link("Send feedback", destination: URL(string: "mailto:support@rivalift.app")!)
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
            }
        }
        .navigationTitle("Settings")
        .onChange(of: settings.unitRaw) { _, _ in env.saveSettings() }
        .onChange(of: settings.compoundRestSec) { _, _ in applyRestDefaults() }
        .onChange(of: settings.isolationRestSec) { _, _ in applyRestDefaults() }
        .onChange(of: settings.restSoundEnabled) { _, _ in env.saveSettings() }
        .onChange(of: settings.restHapticsEnabled) { _, _ in env.saveSettings() }
        .onDisappear { env.saveSettings() }
        .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .task {
            notificationStatus = await env.notifications.authorizationStatus()
            iCloudAvailable = FileManager.default.ubiquityIdentityToken != nil
        }
    }

    /// Target changes apply from next week so the current league week stays fair (section 6.1).
    private func setWeeklyTarget(_ value: Int) {
        let settings = env.settings
        if value == settings.weeklyTarget {
            settings.pendingWeeklyTarget = nil
            settings.pendingTargetEffectiveFrom = nil
        } else {
            settings.pendingWeeklyTarget = value
            settings.pendingTargetEffectiveFrom = WeekCalendar().weekEnd(for: Date())
        }
        env.saveSettings()
    }

    private func applyRestDefaults() {
        env.exercises.applyDefaultRest(compound: env.settings.compoundRestSec, isolation: env.settings.isolationRestSec)
        env.saveSettings()
    }

    private func export() {
        do {
            exportURL = try CSVExporter.exportFile(sessions: env.sessions.completedSessions())
        } catch {
            exportError = error.localizedDescription
        }
    }
}
