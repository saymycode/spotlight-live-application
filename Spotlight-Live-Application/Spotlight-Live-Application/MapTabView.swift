import SwiftUI
import MapKit
import Observation

@Observable
@MainActor
final class MapViewModel {
    var events: [Event] = []
    var isLoading = false
    var selectedEvent: Event?
    var filters = EventFilters()
    var errorMessage: String?

    func loadInitial(appState: AppState) async {
        guard let coordinate = appState.locationManager.lastLocation?.coordinate else { return }
        await fetchEvents(appState: appState, coordinate: coordinate)
    }

    func fetchEvents(appState: AppState, coordinate: CLLocationCoordinate2D) async {
        isLoading = true
        errorMessage = nil
        do {
            events = try await appState.api.fetchNearbyEvents(lat: coordinate.latitude, lng: coordinate.longitude, radiusKm: filters.radiusKm)
        } catch {
            errorMessage = "Etkinlikler yüklenemedi"
        }
        isLoading = false
    }

    var filteredEvents: [Event] {
        events.filter { filters.allows($0) }
    }
}

struct MapTabView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = MapViewModel()
    @State private var mapPosition = MapCameraPosition.region(.init(center: CLLocationCoordinate2D(latitude: 41.015137, longitude: 28.979530), span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)))
    @State private var showCreate = false
    @State private var showFilters = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                Map(position: $mapPosition, selection: $viewModel.selectedEvent) {
                    ForEach(viewModel.filteredEvents) { event in
                        Annotation(event.title, coordinate: event.coordinate) {
                            VStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(event.categoryKey.defaultColor)
                                    .font(.title)
                                Text(event.title)
                                    .font(.caption)
                                    .padding(4)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(8)
                            }
                            .onTapGesture {
                                viewModel.selectedEvent = event
                            }
                        }
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
                .onMapCameraChange { context in
                    if let center = context.region?.center {
                        Task { await viewModel.fetchEvents(appState: appState, coordinate: center) }
                    }
                }
                .sheet(item: $viewModel.selectedEvent) { event in
                    EventDetailView(eventId: event.id)
                }
                .task {
                    appState.locationManager.request()
                    await viewModel.loadInitial(appState: appState)
                }

                VStack(alignment: .trailing, spacing: 12) {
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Button {
                        if let coordinate = appState.locationManager.lastLocation?.coordinate {
                            mapPosition = .region(MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
                        }
                    } label: {
                        Image(systemName: "location.fill")
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                            .padding(14)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding()
            }
            .navigationTitle("Harita")
            .toolbarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCreate) {
                CreateEventView { event in
                    viewModel.events.append(event)
                }
            }
            .sheet(isPresented: $showFilters) {
                EventFilterSheet(filters: $viewModel.filters) {
                    if let center = currentCenter() {
                        Task { await viewModel.fetchEvents(appState: appState, coordinate: center) }
                    }
                }
                .presentationDetents([.fraction(0.3)])
            }
        }
    }

    private func currentCenter() -> CLLocationCoordinate2D? {
        switch mapPosition {
        case .automatic:
            return appState.locationManager.lastLocation?.coordinate
        case .region(let region):
            return region.center
        case .camera(let camera):
            return camera.centerCoordinate
        @unknown default:
            return nil
        }
    }
}

struct EventFilterSheet: View {
    @Binding var filters: EventFilters
    var onApply: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Kategoriler") {
                    ForEach(CategoryKey.allCases, id: \.self) { key in
                        Toggle(isOn: Binding(
                            get: { filters.selectedCategories.contains(key) },
                            set: { isOn in
                                if isOn {
                                    filters.selectedCategories.insert(key)
                                } else {
                                    filters.selectedCategories.remove(key)
                                }
                            })) {
                                Text(key.displayName)
                            }
                    }
                }

                Section("Yarıçap") {
                    Slider(value: $filters.radiusKm, in: 2...25, step: 1) {
                        Text("Yarıçap")
                    } minimumValueLabel: {
                        Text("2km")
                    } maximumValueLabel: {
                        Text("25km")
                    }
                    Text("Seçilen: \(Int(filters.radiusKm)) km")
                }
            }
            .navigationTitle("Filtrele")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Uygula") {
                        onApply()
                    }
                }
            }
        }
    }
}
