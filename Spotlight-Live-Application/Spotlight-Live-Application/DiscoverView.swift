import SwiftUI
import MapKit
import Observation
import FirebaseFirestore

@Observable
@MainActor
final class DiscoverViewModel {
    var events: [Event] = []
    var isLoading = false
    var errorMessage: String?
    @ObservationIgnored var listener: ListenerRegistration?

    func fetch(appState: AppState) async {
        guard let coordinate = appState.locationManager.lastLocation?.coordinate else { return }
        stopListening()
        isLoading = true
        errorMessage = nil
        listener = appState.api.observeNearbyEvents(
            lat: coordinate.latitude,
            lng: coordinate.longitude,
            radiusKm: 50,
            onUpdate: { [weak self] events in
                self?.events = events
                self?.isLoading = false
            },
            onError: { [weak self] _ in
                self?.errorMessage = "Keşfet listesi alınamadı"
                self?.isLoading = false
            }
        )
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}

struct DiscoverView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = DiscoverViewModel()

    var body: some View {
        NavigationStack {
            List(viewModel.events, id: \.id) { event in
                NavigationLink(value: event.id) {
                    EventRow(event: event, userLocation: appState.locationManager.lastLocation?.coordinate)
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .navigationDestination(for: String.self) { id in
                EventDetailView(eventId: id)
            }
            .navigationTitle("Keşfet")
            .task {
                appState.locationManager.request()
                await viewModel.fetch(appState: appState)
            }
            .onDisappear {
                viewModel.stopListening()
            }
            .refreshable {
                await viewModel.fetch(appState: appState)
            }
        }
    }
}

struct EventRow: View {
    let event: Event
    let userLocation: CLLocationCoordinate2D?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(event.title)
                    .font(.headline)
                Spacer()
                categoryChip
            }
            Text(event.startDate.formattedRange(to: event.endDate))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let userLocation {
                let distance = DistanceCalculator.distanceKm(from: userLocation, to: event.coordinate)
                Text(String(format: "%.1f km uzakta", distance))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private var categoryChip: some View {
        Text(event.categoryKey.displayName)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(event.categoryKey.defaultColor.opacity(0.2))
            .foregroundStyle(event.categoryKey.defaultColor)
            .clipShape(Capsule())
    }
}
