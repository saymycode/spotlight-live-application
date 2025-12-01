import SwiftUI
import Observation

struct ContentView: View {
    @State private var appState = AppState()

    var body: some View {
        RootView()
            .environment(appState)
    }
}

#Preview {
    ContentView()
}
