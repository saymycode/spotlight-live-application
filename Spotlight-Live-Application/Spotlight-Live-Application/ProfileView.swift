import SwiftUI
import Observation

@Observable
@MainActor
final class ProfileViewModel {
    var eventsCreated: Int = 0
    var attendedCount: Int = 0

    func load(appState: AppState) async {
        do {
            let events = try await appState.api.fetchMyEvents()
            eventsCreated = events.count
        } catch {
            eventsCreated = 0
        }
    }
}

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ProfileViewModel()

    var body: some View {
        NavigationStack {
            List {
                if let user = appState.currentUser {
                    Section("Bilgiler") {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.largeTitle)
                            VStack(alignment: .leading) {
                                Text(user.displayName)
                                    .font(.headline)
                                Text(user.city)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("İstatistikler") {
                    Label("Oluşturduğum etkinlik: \(viewModel.eventsCreated)", systemImage: "calendar")
                    Label("Katıldıklarım: \(viewModel.attendedCount)", systemImage: "checkmark.seal")
                }

                Section {
                    Button(role: .destructive) {
                        Task { await appState.logout() }
                    } label: {
                        Text("Çıkış yap")
                    }
                }
            }
            .navigationTitle("Profil")
            .task {
                await viewModel.load(appState: appState)
            }
        }
    }
}
