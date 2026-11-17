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
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !iCloudAvailable {
                    notice("Icon_set_icloud", "iCloud is off. Your workouts are only stored on this iPhone. Turn on iCloud or export your data regularly.")
                }

                section("Units") {
                    row("Icon_set_unit", "Weight Unit") {
                        Menu {
                            Picker("Weight unit", selection: $settings.unitRaw) {
                                Text("Kilograms (kg)").tag(WeightUnit.kg.rawValue)
                                Text("Pounds (lb)").tag(WeightUnit.lb.rawValue)
                            }
                        } label: {
                            pill(settings.unitRaw == WeightUnit.lb.rawValue ? String(localized: "Pounds (lb)") : String(localized: "Kilograms (kg)"))
                        }
                    }
                }

                section("Training") {
                    row("Icon_set_target", "Weekly Target") {
                        let value = settings.pendingWeeklyTarget ?? settings.weeklyTarget
                        HStack(spacing: 12) {
                            Text("\(value)").font(.subheadline).monospacedDigit()
                            HStack(spacing: 0) {
                                stepButton("minus", "Decrease weekly target", enabled: value > 1) { setWeeklyTarget(value - 1) }
                                Rectangle().fill(.white.opacity(0.2)).frame(width: 0.5, height: 16)
                                stepButton("plus", "Increase weekly target", enabled: value < 7) { setWeeklyTarget(value + 1) }
                            }
                            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .padding(.leading, 13)
                        .padding(.trailing, 7)
                        .padding(.vertical, 7)
                        .background(fieldBackground)
                    }
                    if settings.pendingWeeklyTarget != nil {
                        Text("Your new target starts next Monday.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                section("Rest Timer") {
                    row("Icon_set_timer", "Compound Exercises") { restMenu($settings.compoundRestSec) }
                    divider
                    row("Icon_set_timer", "Isolation Exercises") { restMenu($settings.isolationRestSec) }
                    divider
                    row("Icon_set_sound", "Sound") { Toggle("Sound", isOn: $settings.restSoundEnabled).labelsHidden().tint(.green) }
                    divider
                    row("Icon_set_vibe", "Vibration") { Toggle("Vibration", isOn: $settings.restHapticsEnabled).labelsHidden().tint(.green) }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Notifications").padding(.horizontal, 4)
                    if notificationStatus == .denied {
                        notice("Icon_set_bell", "Notifications are off for Rivalift. Enable them in iOS Settings.") {
                            Button("Open iOS Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                            }
                            .font(.subheadline.weight(.medium))
                        }
                    }
                    card {
                        toggle("Rest timer finished", $settings.notifyRestTimer)
                        divider
                        toggle("Workout reminders", $settings.notifyWorkoutReminder)
                        if settings.notifyWorkoutReminder {
                            WeekdayPicker(selection: $settings.trainingWeekdays)
                            HStack {
                                Text(settings.trainingWeekdays.isEmpty ? "Pick your training days" : "Remind me at")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 8)
                                Menu {
                                    Picker("Reminder time", selection: $settings.reminderHour) {
                                        ForEach(5..<23, id: \.self) { Text(hourLabel($0)).tag($0) }
                                    }
                                } label: {
                                    pill(hourLabel(settings.reminderHour))
                                }
                                .accessibilityLabel("Reminder time")
                            }
                        }
                        divider
                        toggle("Overtaken in a league", $settings.notifyOvertaken)
                        divider
                        toggle("Close to ranking up", $settings.notifyAlmostRankUp)
                        divider
                        toggle("League results", $settings.notifyLeagueResults)
                        divider
                        toggle("New group members", $settings.notifyNewMember)
                    }
                }

                section("Data") {
                    Button { export() } label: {
                        Label("Export workouts (CSV)", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: Theme.minTap, alignment: .leading)
                    }
                    if let exportURL {
                        divider
                        ShareLink("Share export", item: exportURL).frame(maxWidth: .infinity, minHeight: Theme.minTap, alignment: .leading)
                    }
                }

                section("Account") {
                    Text("Sign in with Apple arrives with leagues. Everything works without an account.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                section("About") {
                    link("Privacy policy", "https://rivalift.app/privacy")
                    divider
                    link("Terms of service", "https://rivalift.app/terms")
                    divider
                    link("Send feedback", "mailto:support@rivalift.app")
                    divider
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                        .frame(minHeight: Theme.minTap)
                }
            }
            .padding()
        }
        .screenBackground()
        .navigationTitle("Settings")
        .onChange(of: settings.unitRaw) { _, _ in env.saveSettings() }
        .onChange(of: settings.compoundRestSec) { _, _ in applyRestDefaults() }
        .onChange(of: settings.isolationRestSec) { _, _ in applyRestDefaults() }
        .onChange(of: settings.restSoundEnabled) { _, _ in env.saveSettings() }
        .onChange(of: settings.restHapticsEnabled) { _, _ in env.saveSettings() }
        .onChange(of: settings.notifyWorkoutReminder) { _, on in
            env.saveSettings()
            if on && notificationStatus == .notDetermined {
                Task {
                    _ = await env.notifications.requestAuthorization()
                    notificationStatus = await env.notifications.authorizationStatus()
                    env.refreshWorkoutReminders()
                }
            }
        }
        .onChange(of: settings.reminderWeekdaysRaw) { _, _ in env.saveSettings() }
        .onChange(of: settings.reminderHour) { _, _ in env.saveSettings() }
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

    // MARK: Building blocks (Figma "Settings")

    private var divider: some View { GlassDivider() }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.white.opacity(0.1))
            .strokeBorder(.white.opacity(0.2))
    }

    private func card(@ViewBuilder _ content: () -> some View) -> some View {
        GlassCard(content: content)
    }

    private func section(_ title: LocalizedStringKey, @ViewBuilder _ content: () -> some View) -> some View {
        GlassSection(title, content: content)
    }

    private func row(_ icon: String, _ title: LocalizedStringKey, @ViewBuilder trailing: () -> some View) -> some View {
        GlassRow(icon: icon, title: title, trailing: trailing)
    }

    private func notice(_ icon: String, _ text: LocalizedStringKey, @ViewBuilder action: () -> some View = { EmptyView() }) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RingIcon(image: icon, strong: true)
                Text(text).font(.subheadline)
            }
            action()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dotTexture(alignment: .center, x: 14, y: -79.46)
        .glassCard()
    }

    private func pill(_ text: String) -> some View { PillMenuLabel(text: text) }

    private func hourLabel(_ hour: Int) -> String {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())?.formatted(date: .omitted, time: .shortened) ?? "\(hour):00"
    }

    private func restMenu(_ value: Binding<Int>) -> some View {
        Menu {
            Picker("Rest", selection: value) {
                ForEach(restOptions, id: \.self) { Text(DurationFormatter.clock($0)).tag($0) }
            }
        } label: {
            pill(DurationFormatter.clock(value.wrappedValue))
        }
    }

    private func stepButton(_ symbol: String, _ label: LocalizedStringKey, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 33, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(label)
    }

    private func toggle(_ title: LocalizedStringKey, _ isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn).font(.subheadline).tint(.green)
    }

    private func link(_ title: LocalizedStringKey, _ url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Text(title).font(.subheadline).foregroundStyle(.white)
                Spacer()
                Image("IconChevronCircle").accessibilityHidden(true)
            }
            .frame(minHeight: Theme.minTap)
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
