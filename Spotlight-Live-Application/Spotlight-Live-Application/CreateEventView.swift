import SwiftUI
import MapKit
import Observation

@Observable
@MainActor
final class CreateEventViewModel {
    var title: String = ""
    var description: String = ""
    var selectedCategory: CategoryKey = .culture
    var startDate: Date = Date()
    var endDate: Date = Date().addingTimeInterval(3600)
    var coordinate: CLLocationCoordinate2D?
    var isPublic: Bool = true
    var isSubmitting = false
    var errorMessage: String?

    func canSubmit() -> Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && startDate < endDate && coordinate != nil
    }

    func submit(appState: AppState) async throws -> Event {
        guard let coordinate else { throw URLError(.badURL) }
        isSubmitting = true
        defer { isSubmitting = false }
        let request = CreateEventRequest(
            title: title,
            description: description,
            categoryKey: selectedCategory,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            startTimeUtc: startDate,
            endTimeUtc: endDate,
            isPublic: isPublic
        )
        return try await appState.api.createEvent(request)
    }
}

struct CreateEventView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var viewModel = CreateEventViewModel()
    var onCreated: (Event) -> Void

    @State private var mapPosition = MapCameraPosition.region(.init(center: CLLocationCoordinate2D(latitude: 41.015137, longitude: 28.979530), span: .init(latitudeDelta: 0.05, longitudeDelta: 0.05)))
    @State private var marker: MKMapItem?

    var body: some View {
        NavigationStack {
            Form {
                Section("Başlık") {
                    TextField("Etkinlik başlığı", text: $viewModel.title)
                }

                Section("Kategori") {
                    Picker("Kategori", selection: $viewModel.selectedCategory) {
                        ForEach(CategoryKey.allCases, id: \.self) { key in
                            Text(key.displayName).tag(key)
                        }
                    }
                }

                Section("Tarih") {
                    DatePicker("Başlangıç", selection: $viewModel.startDate)
                    DatePicker("Bitiş", selection: $viewModel.endDate)
                }

                Section("Konum") {
                    MapReader { reader in
                        Map(position: $mapPosition, interactionModes: [.all]) {
                            if let marker {
                                Marker(viewModel.title.isEmpty ? "Konum" : viewModel.title, coordinate: marker.placemark.coordinate)
                            }
                        }
                        .frame(height: 200)
                        .onTapGesture { location in
                            if let coordinate = reader.convert(location, from: .local) {
                                updateMarker(coordinate)
                            }
                        }
                    }
                }

                Section("Açıklama") {
                    TextEditor(text: $viewModel.description)
                        .frame(height: 120)
                }

                Section {
                    Toggle("Herkese açık", isOn: $viewModel.isPublic)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                }

                Button("Oluştur") {
                    Task {
                        do {
                            let event = try await viewModel.submit(appState: appState)
                            onCreated(event)
                            dismiss()
                        } catch {
                            viewModel.errorMessage = error.localizedDescription
                        }
                    }
                }
                .disabled(!viewModel.canSubmit())
            }
            .navigationTitle("Etkinlik oluştur")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
            }
            .task {
                appState.locationManager.request()
                if let coordinate = appState.locationManager.lastLocation?.coordinate {
                    mapPosition = .region(MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
                    updateMarker(coordinate)
                }
            }
        }
    }

    private func updateMarker(_ coordinate: CLLocationCoordinate2D) {
        viewModel.coordinate = coordinate
        marker = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
    }
}
