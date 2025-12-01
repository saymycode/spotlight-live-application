import SwiftUI
import Observation

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.token == nil || appState.currentUser == nil {
                AuthView()
            } else {
                MainTabView()
            }
        }
        .task {
            if appState.token != nil, appState.currentUser == nil {
                // Optionally fetch profile endpoint; for now rely on saved token.
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            MapTabView()
                .tabItem {
                    Label("Harita", systemImage: "map")
                }
            DiscoverView()
                .tabItem {
                    Label("Keşfet", systemImage: "sparkles")
                }
            MyEventsView()
                .tabItem {
                    Label("Etkinliklerim", systemImage: "calendar")
                }
            ProfileView()
                .tabItem {
                    Label("Profil", systemImage: "person.circle")
                }
        }
    }
}
