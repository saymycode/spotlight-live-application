import SwiftUI
import Observation
import FirebaseCore

@main
struct Spotlight_Live_ApplicationApp: App {
    @State private var appState = AppState()

    init() {
        print("[App] init: configuring Firebase...")
        FirebaseService.shared.configureIfNeeded()
        print("[App] init: Firebase configureIfNeeded called.")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
    }
}
