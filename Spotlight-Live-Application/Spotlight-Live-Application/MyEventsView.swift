import SwiftUI
import Observation
internal import _LocationEssentials

@Observable
@MainActor
final class MyEventsViewModel {
    var createdEvents: [Event] = []
    var attendingEvents: [Event] = []
    var isLoading = false
    var errorMessage: String?

    func fetch(appState: AppState) async {
        isLoading = true
        errorMessage = nil
        do {
            createdEvents = try await appState.api.fetchMyEvents()
        } catch {
            errorMessage = "Etkinlikler getirilemedi"
        }
        isLoading = false
    }
}

struct MyEventsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = MyEventsViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("Oluşturduklarım") {
                    ForEach(viewModel.createdEvents, id: \.id) { event in
                        NavigationLink(value: event.id) {
                            EventRow(
                                event: event,
                                userLocation: appState.locationManager.lastLocation?.coordinate
                            )
                        }
                    }
                }
            }
            .navigationDestination(for: String.self) { id in
                EventDetailView(eventId: id)
            }
            .navigationTitle("Etkinliklerim")
            .task {
                await viewModel.fetch(appState: appState)
            }
            .refreshable {
                await viewModel.fetch(appState: appState)
            }
        }
    }
}
