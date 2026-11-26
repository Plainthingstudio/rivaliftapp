import SwiftUI

/// Quick Workout: pick equipment, time and focus, get one workout for today. The plan stays
/// as it is; the session still counts for the streak and the league.
struct QuickWorkoutView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var kit: QuickWorkout.Kit = .gym
    @State private var minutes = 30
    @State private var focus: QuickWorkout.Focus = .fullBody
    @State private var shuffle = 0

    var body: some View {
        let workout = env.quickWorkout(kit: kit, minutes: minutes, focus: focus, shuffle: shuffle)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Away from your usual gym or short on time? Get one workout for today. Your plan stays as it is.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                choices("WHAT DO YOU HAVE?", QuickWorkout.Kit.allCases, selection: $kit, label: Self.name)
                choices("HOW LONG?", QuickWorkout.minutes, selection: $minutes) { String(localized: "\($0) min") }
                choices("FOCUS", QuickWorkout.Focus.allCases, selection: $focus, label: Self.name)
                list(workout)
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                env.workout.requestStart(.quick(workout.map(\.item)))
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image("IconPlay").accessibilityHidden(true)
                    Text("Start workout")
                }
            }
            .buttonStyle(.primary)
            .disabled(workout.isEmpty)
            .accessibilityIdentifier("startQuickWorkout")
            .padding(.horizontal)
            .padding(.top, 28)
            .padding(.bottom, 8)
            .background(Theme.bottomFade)
        }
        .screenBackground()
        .navigationTitle("Quick Workout")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: kit) { _, _ in shuffle = 0 }
        .onChange(of: focus) { _, _ in shuffle = 0 }
    }

    private func choices<Value: Hashable>(_ title: LocalizedStringKey, _ values: [Value], selection: Binding<Value>, label: @escaping (Value) -> String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(values, id: \.self) { value in
                        let selected = value == selection.wrappedValue
                        Button { selection.wrappedValue = value } label: {
                            FilterPill(title: label(value), isSelected: selected)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
        }
    }

    private func list(_ workout: [(item: QuickWorkout.Item, exercise: Exercise)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your workout").font(.headline.weight(.medium))
                    Text("^[\(workout.count) exercise](inflect: true) · \(minutes) min").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { shuffle += 1 } label: {
                    Image(systemName: "shuffle")
                        .font(.subheadline)
                        .frame(width: Theme.minTap, height: Theme.minTap)
                        .background(Theme.glassFill, in: Circle())
                        .overlay(Circle().strokeBorder(Theme.border))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Shuffle exercises")
                .accessibilityIdentifier("shuffleQuickWorkout")
            }
            if workout.isEmpty {
                Text("No exercises fit this equipment and focus yet. Try another choice.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(workout.enumerated()), id: \.element.item.id) { index, entry in
                if index > 0 { GlassDivider() }
                NavigationLink { ExerciseDetailView(exercise: entry.exercise) } label: {
                    HStack(spacing: 12) {
                        ExercisePhoto(exercise: entry.exercise, width: 56, height: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.exercise.name).font(.subheadline)
                            Text(entry.item.reps > 0 ? "\(entry.item.sets) × \(entry.item.reps)" : String(localized: "\(entry.item.sets) sets"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .combine)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    static func name(_ kit: QuickWorkout.Kit) -> String {
        switch kit {
        case .gym: String(localized: "Full gym")
        case .dumbbells: String(localized: "Dumbbells")
        case .none: String(localized: "No equipment")
        case .bands: String(localized: "Bands")
        }
    }

    static func name(_ focus: QuickWorkout.Focus) -> String {
        switch focus {
        case .fullBody: String(localized: "Full body")
        case .upper: String(localized: "Upper body")
        case .legs: String(localized: "Legs")
        case .core: String(localized: "Core")
        }
    }
}
