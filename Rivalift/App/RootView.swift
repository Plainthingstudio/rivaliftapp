import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if env.settings.onboardingDone {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                env.workout.checkStaleSession()
                env.refreshWorkoutReminders()
                Task { await env.sync.processQueue() }
            }
        }
    }
}

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        @Bindable var env = env
        @Bindable var workout = env.workout
        TabView(selection: $env.selectedTab) {
            NavigationStack { HomeView() }
                .tint(Theme.accent)
                .workoutMiniBar()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.home)
            NavigationStack { LibraryView() }
                .tint(Theme.accent)
                .workoutMiniBar()
                .tabItem { Label("Library", systemImage: "books.vertical.fill") }
                .tag(AppTab.library)
            NavigationStack { LeaguesView() }
                .tint(Theme.accent)
                .workoutMiniBar()
                .tabItem { Label("Leagues", systemImage: "trophy.fill") }
                .tag(AppTab.leagues)
            NavigationStack { ProfileView() }
                .tint(Theme.accent)
                .workoutMiniBar()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
        .tint(Theme.accent) // selected tab; content below keeps the app accent
        .fullScreenCover(isPresented: $workout.isPresented) {
            ActiveWorkoutView()
                .environment(env)
                .tint(Theme.accent)
        }
        .sheet(item: $workout.summary) { summary in
            WorkoutSummaryView(summary: summary)
                .environment(env)
                .tint(Theme.accent)
                .interactiveDismissDisabled()
        }
        .startConflictAlert()
        .alert("Workout still running", isPresented: $workout.isStalePromptPresented) {
            Button("Finish at last set") { env.workout.finishStaleAtLastSet() }
            Button("Discard workout", role: .destructive) { env.workout.discard() }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("This workout has been open for more than 6 hours.")
        }
    }
}

private struct WorkoutMiniBarModifier: ViewModifier {
    @Environment(AppEnvironment.self) private var env

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            if let session = env.workout.session, !env.workout.isPresented {
                MiniWorkoutBar(session: session) { env.workout.isPresented = true }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
    }
}

extension View {
    func workoutMiniBar() -> some View { modifier(WorkoutMiniBarModifier()) }
}
