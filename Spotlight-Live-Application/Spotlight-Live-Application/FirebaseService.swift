import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift
import MapKit

struct FirestoreKeys {
    static let users = "users"
    static let events = "events"
    static let categories = "categories"
    static let attendance = "attendance"
}

final class FirebaseService {
    static let shared = FirebaseService()
    private var isConfigured = false

    private init() {}

    func configureIfNeeded() {
        guard FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
        isConfigured = true
    }

    // MARK: - Auth

    func register(email: String, password: String, displayName: String, city: String) async throws -> AuthResponse {
        let result = try await auth.createUser(withEmail: email, password: password)
        let profile = User(
            id: result.user.uid,
            displayName: displayName,
            avatarUrl: nil,
            city: city,
            createdAtUtc: Date()
        )
        try await saveUserProfile(profile)
        let token = try await result.user.getIDToken()
        return AuthResponse(token: token, user: profile)
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let result = try await auth.signIn(withEmail: email, password: password)
        let profile = try await fetchUserProfile(uid: result.user.uid)
        let token = try await result.user.getIDToken()
        return AuthResponse(token: token, user: profile)
    }

    func restoreSession() async -> AuthResponse? {
        guard let user = auth.currentUser else { return nil }
        do {
            let profile = try await fetchUserProfile(uid: user.uid)
            let token = try await user.getIDToken()
            return AuthResponse(token: token, user: profile)
        } catch {
            return nil
        }
    }

    func logout() async {
        do { try auth.signOut() } catch { print("SignOut failed: \(error)") }
    }

    // MARK: - Catalog

    func fetchCategories() async throws -> [EventCategory] {
        let snapshot = try await db.collection(FirestoreKeys.categories).getDocuments()
        if snapshot.documents.isEmpty {
            return EventCategory.sample
        }
        return try snapshot.documents.compactMap { document in
            try document.data(as: EventCategory.self)
        }
    }

    // MARK: - Events

    func fetchNearbyEvents(lat: Double, lng: Double, radiusKm: Double) async throws -> [Event] {
        let snapshot = try await db.collection(FirestoreKeys.events)
            .order(by: "startTimeUtc")
            .getDocuments()
        let userLocation = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let events: [Event] = snapshot.documents.compactMap { doc in
            guard let event = try? doc.data(as: Event.self) else { return nil }
            let distance = DistanceCalculator.distanceKm(from: userLocation, to: event.coordinate)
            return distance <= radiusKm ? event : nil
        }
        return events
    }

    func fetchEventDetail(id: String) async throws -> Event {
        try await db.collection(FirestoreKeys.events)
            .document(id)
            .getDocument(as: Event.self)
    }

    func createEvent(_ request: CreateEventRequest, userId: String) async throws -> Event {
        let docRef = db.collection(FirestoreKeys.events).document()
        let now = Date()
        let event = Event(
            id: docRef.documentID,
            title: request.title,
            description: request.description,
            categoryKey: request.categoryKey,
            latitude: request.latitude,
            longitude: request.longitude,
            startTimeUtc: request.startTimeUtc,
            endTimeUtc: request.endTimeUtc,
            createdAtUtc: now,
            createdByUserId: userId,
            isPublic: request.isPublic
        )
        try docRef.setData(from: event)
        return event
    }

    func fetchMyEvents(userId: String) async throws -> [Event] {
        let snapshot = try await db.collection(FirestoreKeys.events)
            .whereField("createdByUserId", isEqualTo: userId)
            .order(by: "startTimeUtc", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Event.self) }
    }

    // MARK: - Attendance

    func fetchAttendance(eventId: String) async throws -> [EventAttendance] {
        let snapshot = try await db.collection(FirestoreKeys.attendance)
            .whereField("eventId", isEqualTo: eventId)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: EventAttendance.self) }
    }

    func setAttendance(eventId: String, status: AttendanceStatus, userId: String) async throws -> EventAttendance {
        let documentId = "\(eventId)-\(userId)"
        let docRef = db.collection(FirestoreKeys.attendance).document(documentId)
        let record = EventAttendance(
            id: documentId,
            eventId: eventId,
            userId: userId,
            status: status,
            createdAtUtc: Date()
        )
        try docRef.setData(from: record)
        return record
    }

    // MARK: - Private

    private var auth: Auth {
        configureIfNeeded()
        return Auth.auth()
    }

    private var db: Firestore {
        configureIfNeeded()
        return Firestore.firestore()
    }

    private func saveUserProfile(_ profile: User) async throws {
        let ref = db.collection(FirestoreKeys.users).document(profile.id)
        try ref.setData(from: profile)
    }

    private func fetchUserProfile(uid: String) async throws -> User {
        try await db.collection(FirestoreKeys.users)
            .document(uid)
            .getDocument(as: User.self)
    }
}
