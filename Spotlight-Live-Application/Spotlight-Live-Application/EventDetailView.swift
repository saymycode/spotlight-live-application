import SwiftUI
import MapKit
import Observation

@Observable
@MainActor
final class EventDetailViewModel {
    var event: Event?
    var attendance: [EventAttendance] = []
    var isLoading = false
    var errorMessage: String?
    var myStatus: AttendanceStatus?

    func fetch(eventId: String, appState: AppState) async {
        isLoading = true
        errorMessage = nil
        do {
            async let eventTask = appState.api.fetchEventDetail(id: eventId)
            async let attendanceTask = appState.api.fetchEventAttendance(eventId: eventId)
            event = try await eventTask
            attendance = try await attendanceTask
            myStatus = attendance.first(where: { $0.userId == appState.currentUser?.id })?.status
        } catch {
            errorMessage = "Detay yüklenemedi"
        }
        isLoading = false
    }

    func setAttendance(appState: AppState, eventId: String, status: AttendanceStatus) async {
        do {
            let record = try await appState.api.setAttendance(eventId: eventId, status: status)
            myStatus = record.status
            if let index = attendance.firstIndex(where: { $0.id == record.id }) {
                attendance[index] = record
            } else {
                attendance.append(record)
            }
        } catch {
            errorMessage = "Katılım kaydedilemedi"
        }
    }
}

struct EventDetailView: View {
    let eventId: String
    @Environment(AppState.self) private var appState
    @State private var viewModel = EventDetailViewModel()

    var body: some View {
        ScrollView {
            if let event = viewModel.event {
                VStack(alignment: .leading, spacing: 16) {
                    Text(event.title)
                        .font(.title)
                        .bold()
                    categoryChip(for: event)
                    Text(event.startDate.formattedRange(to: event.endDate))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    mapPreview(for: event)
                    Text(event.description)
                        .font(.body)
                    hostSection(event: event)
                    attendanceSection(event: event)
                }
                .padding()
            }
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .navigationTitle("Detay")
        .toolbarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetch(eventId: eventId, appState: appState)
        }
    }

    private func categoryChip(for event: Event) -> some View {
        Text(event.categoryKey.displayName)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(event.categoryKey.defaultColor.opacity(0.2))
            .foregroundStyle(event.categoryKey.defaultColor)
            .clipShape(Capsule())
    }

    private func mapPreview(for event: Event) -> some View {
        Map(position: .constant(.region(MKCoordinateRegion(center: event.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))))) {
            Annotation("", coordinate: event.coordinate) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(event.categoryKey.defaultColor)
            }
        }
        .frame(height: 200)
        .cornerRadius(12)
    }

    private func hostSection(event: Event) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ev sahibi")
                .font(.headline)
            Text(event.createdByUserId)
                .foregroundStyle(.secondary)
        }
    }

    private func attendanceSection(event: Event) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Katılım")
                .font(.headline)
            HStack {
                ForEach(AttendanceStatus.allCases, id: \.self) { status in
                    Button {
                        Task { await viewModel.setAttendance(appState: appState, eventId: event.id, status: status) }
                    } label: {
                        Text(status.title)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(viewModel.myStatus == status ? statusColor(status).opacity(0.2) : Color(.systemGray6))
                            .foregroundStyle(viewModel.myStatus == status ? statusColor(status) : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            let counts = EventAttendance.counts(for: viewModel.attendance)
            Text("\(counts.going) kişi katılıyor, \(counts.maybe) kişi kararsız.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func statusColor(_ status: AttendanceStatus) -> Color {
        switch status {
        case .going: return .green
        case .maybe: return .orange
        case .notGoing: return .red
        }
    }
}
