import SwiftUI

@main
struct RivaliftApp: App {
    @State private var environment: AppEnvironment

    init() {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        _environment = State(initialValue: AppEnvironment(inMemory: isUITesting))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
        }
    }
}
