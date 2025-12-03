import Foundation
import MapKit

actor ApiClient {
    static let shared = ApiClient()

    private let firebase = FirebaseService.shared
    private var token: String?

    func setToken(_ token: String?) {
        self.token = token
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let response = try await firebase.login(email: email, password: password)
        token = response.token
        return response
    }

    func register(email: String, password: String, displayName: String, city: String) async throws -> AuthResponse {
        let response = try await firebase.register(email: email, password: password, displayName: displayName, city: city)
        token = response.token
        return response
    }

    func restoreSession() async -> AuthResponse? {
        if let session = await firebase.restoreSession() {
            token = session.token
            return session
        }
        return nil
    }

    func fetchCategories() async throws -> [EventCategory] {
        try await firebase.fetchCategories()
    }

    func fetchNearbyEvents(lat: Double, lng: Double, radiusKm: Double) async throws -> [Event] {
        try await firebase.fetchNearbyEvents(lat: lat, lng: lng, radiusKm: radiusKm)
    }

    func fetchEventDetail(id: String) async throws -> Event {
        try await firebase.fetchEventDetail(id: id)
    }

    func createEvent(_ requestBody: CreateEventRequest, userId: String) async throws -> Event {
        try await firebase.createEvent(requestBody, userId: userId)
    }

    func fetchEventAttendance(eventId: String) async throws -> [EventAttendance] {
        try await firebase.fetchAttendance(eventId: eventId)
    }

    func setAttendance(eventId: String, status: AttendanceStatus, userId: String) async throws -> EventAttendance {
        try await firebase.setAttendance(eventId: eventId, status: status, userId: userId)
    }

    func fetchMyEvents(userId: String) async throws -> [Event] {
        try await firebase.fetchMyEvents(userId: userId)
    }

    func restoreUserFromToken(_ token: String) async -> User? {
        guard let session = await firebase.restoreSession() else { return nil }
        return session.user
    }

    func logout() async {
        await firebase.logout()
        token = nil
    }
}

struct CreateEventRequest: Encodable {
    let title: String
    let description: String
    let categoryKey: CategoryKey
    let latitude: Double
    let longitude: Double
    let startTimeUtc: Date
    let endTimeUtc: Date
    let isPublic: Bool
}
