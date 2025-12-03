import SwiftUI
import Observation
import FirebaseCore

@main
struct Spotlight_Live_ApplicationApp: App {
    @State private var appState = AppState()

    init() {
        FirebaseService.shared.configureIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
    }
}
