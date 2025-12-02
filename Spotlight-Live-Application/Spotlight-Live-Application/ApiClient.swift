import Foundation
import MapKit

actor ApiClient {
    static let shared = ApiClient()

    private let baseURL = URL(string: "http://localhost:5000/api")!
    private var token: String?
    private var isOfflineMode = true
    private let mockStore = MockDataStore()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    func setToken(_ token: String?) {
        self.token = token
    }

    private func request(path: String, method: String = "GET", queryItems: [URLQueryItem] = [], body: Encodable? = nil, authorized: Bool = false) async throws -> Data {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authorized, let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        if isOfflineMode {
            let response = try await mockStore.login(email: email, password: password)
            token = response.token
            return response
        }
        let payload = ["email": email, "password": password]
        let data = try await request(path: "auth/login", method: "POST", body: payload)
        return try decoder.decode(AuthResponse.self, from: data)
    }

    func register(email: String, password: String, displayName: String, city: String) async throws -> AuthResponse {
        if isOfflineMode {
            let response = try await mockStore.register(email: email, password: password, displayName: displayName, city: city)
            token = response.token
            return response
        }
        let payload = [
            "email": email,
            "password": password,
            "displayName": displayName,
            "city": city
        ]
        let data = try await request(path: "auth/register", method: "POST", body: payload)
        return try decoder.decode(AuthResponse.self, from: data)
    }

    func fetchCategories() async throws -> [EventCategory] {
        if isOfflineMode {
            return await mockStore.fetchCategories()
        }
        let data = try await request(path: "categories")
        return try decoder.decode([EventCategory].self, from: data)
    }

    func fetchNearbyEvents(lat: Double, lng: Double, radiusKm: Double) async throws -> [Event] {
        if isOfflineMode {
            return await mockStore.fetchNearbyEvents(lat: lat, lng: lng, radiusKm: radiusKm)
        }
        let query = [
            URLQueryItem(name: "lat", value: String(lat)),
            URLQueryItem(name: "lng", value: String(lng)),
            URLQueryItem(name: "radiusKm", value: String(radiusKm))
        ]
        let data = try await request(path: "events/near", queryItems: query)
        return try decoder.decode([Event].self, from: data)
    }

    func fetchEventDetail(id: String) async throws -> Event {
        if isOfflineMode {
            return try await mockStore.fetchEventDetail(id: id)
        }
        let data = try await request(path: "events/\(id)")
        return try decoder.decode(Event.self, from: data)
    }

    func createEvent(_ requestBody: CreateEventRequest) async throws -> Event {
        if isOfflineMode {
            return try await mockStore.createEvent(requestBody, token: token)
        }
        let data = try await request(path: "events", method: "POST", body: requestBody, authorized: true)
        return try decoder.decode(Event.self, from: data)
    }

    func fetchEventAttendance(eventId: String) async throws -> [EventAttendance] {
        if isOfflineMode {
            return await mockStore.fetchEventAttendance(eventId: eventId)
        }
        let data = try await request(path: "events/\(eventId)/attendance")
        return try decoder.decode([EventAttendance].self, from: data)
    }

    func setAttendance(eventId: String, status: AttendanceStatus) async throws -> EventAttendance {
        if isOfflineMode {
            return try await mockStore.setAttendance(eventId: eventId, status: status, token: token)
        }
        let payload = ["status": status.rawValue]
        let data = try await request(path: "events/\(eventId)/attendance", method: "POST", body: payload, authorized: true)
        return try decoder.decode(EventAttendance.self, from: data)
    }

    func fetchMyEvents() async throws -> [Event] {
        if isOfflineMode {
            return try await mockStore.fetchMyEvents(token: token)
        }
        let data = try await request(path: "me/events", authorized: true)
        return try decoder.decode([Event].self, from: data)
    }

    func restoreUserFromToken(_ token: String) async -> User? {
        guard isOfflineMode else { return nil }
        return await mockStore.user(for: token)
    }
}

private struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void

    init<E: Encodable>(_ encodable: E) {
        self.encodeFunc = encodable.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
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

actor MockDataStore {
    private var categories: [EventCategory] = CategoryKey.allCases.map {
        EventCategory(id: UUID().uuidString, key: $0, name: $0.displayName, colorHex: "")
    }
    private var accounts: [String: User] = [:] // email -> user
    private var tokens: [String: String] = [:] // token -> email
    private var events: [Event] = []
    private var attendance: [EventAttendance] = []

    init() {
        let defaultUser = User(
            id: UUID().uuidString,
            displayName: "Demo Kullanıcı",
            avatarUrl: nil,
            city: "İstanbul",
            createdAtUtc: Date()
        )
        accounts["demo@spotlight.live"] = defaultUser

        let now = Date()
        events = [
            Event(
                id: UUID().uuidString,
                title: "Açık Hava Film Gecesi",
                description: "Boğaz manzarası eşliğinde klasik film gösterimi.",
                categoryKey: .culture,
                latitude: 41.0392,
                longitude: 29.0153,
                startTimeUtc: now.addingTimeInterval(3600),
                endTimeUtc: now.addingTimeInterval(7200),
                createdAtUtc: now,
                createdByUserId: defaultUser.id,
                isPublic: true
            ),
            Event(
                id: UUID().uuidString,
                title: "Sabah Koşusu",
                description: "Maçka Parkı'nda 5K koşu ve stretching.",
                categoryKey: .sports,
                latitude: 41.0421,
                longitude: 28.9860,
                startTimeUtc: now.addingTimeInterval(10800),
                endTimeUtc: now.addingTimeInterval(14400),
                createdAtUtc: now,
                createdByUserId: defaultUser.id,
                isPublic: true
            ),
            Event(
                id: UUID().uuidString,
                title: "Teras DJ Set",
                description: "Şehir manzarasında canlı DJ performansı.",
                categoryKey: .night,
                latitude: 41.0266,
                longitude: 28.9780,
                startTimeUtc: now.addingTimeInterval(18000),
                endTimeUtc: now.addingTimeInterval(21600),
                createdAtUtc: now,
                createdByUserId: defaultUser.id,
                isPublic: true
            )
        ]

        attendance = [
            EventAttendance(
                id: UUID().uuidString,
                eventId: events[0].id,
                userId: defaultUser.id,
                status: .going,
                createdAtUtc: now
            )
        ]
    }

    func login(email: String, password: String) throws -> AuthResponse {
        let user = accounts[email] ?? createUser(email: email, displayName: email.components(separatedBy: "@").first ?? "Kullanıcı", city: "İstanbul")
        accounts[email] = user
        let token = UUID().uuidString
        tokens[token] = email
        return AuthResponse(token: token, user: user)
    }

    func register(email: String, password: String, displayName: String, city: String) throws -> AuthResponse {
        let user = createUser(email: email, displayName: displayName, city: city)
        accounts[email] = user
        let token = UUID().uuidString
        tokens[token] = email
        return AuthResponse(token: token, user: user)
    }

    func fetchCategories() -> [EventCategory] {
        categories
    }

    func fetchNearbyEvents(lat: Double, lng: Double, radiusKm: Double) -> [Event] {
        let origin = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        return events.filter { event in
            let distance = DistanceCalculator.distanceKm(from: origin, to: event.coordinate)
            return distance <= radiusKm
        }
    }

    func fetchEventDetail(id: String) throws -> Event {
        guard let event = events.first(where: { $0.id == id }) else {
            throw URLError(.fileDoesNotExist)
        }
        return event
    }

    func createEvent(_ requestBody: CreateEventRequest, token: String?) throws -> Event {
        guard let token, let user = user(for: token) else { throw URLError(.userAuthenticationRequired) }
        let event = Event(
            id: UUID().uuidString,
            title: requestBody.title,
            description: requestBody.description,
            categoryKey: requestBody.categoryKey,
            latitude: requestBody.latitude,
            longitude: requestBody.longitude,
            startTimeUtc: requestBody.startTimeUtc,
            endTimeUtc: requestBody.endTimeUtc,
            createdAtUtc: Date(),
            createdByUserId: user.id,
            isPublic: requestBody.isPublic
        )
        events.append(event)
        return event
    }

    func fetchEventAttendance(eventId: String) -> [EventAttendance] {
        attendance.filter { $0.eventId == eventId }
    }

    func setAttendance(eventId: String, status: AttendanceStatus, token: String?) throws -> EventAttendance {
        guard let token, let user = user(for: token) else { throw URLError(.userAuthenticationRequired) }
        if let index = attendance.firstIndex(where: { $0.eventId == eventId && $0.userId == user.id }) {
            let updated = EventAttendance(
                id: attendance[index].id,
                eventId: eventId,
                userId: user.id,
                status: status,
                createdAtUtc: Date()
            )
            attendance[index] = updated
            return updated
        }
        let record = EventAttendance(
            id: UUID().uuidString,
            eventId: eventId,
            userId: user.id,
            status: status,
            createdAtUtc: Date()
        )
        attendance.append(record)
        return record
    }

    func fetchMyEvents(token: String?) throws -> [Event] {
        guard let token, let user = user(for: token) else { throw URLError(.userAuthenticationRequired) }
        return events.filter { $0.createdByUserId == user.id }
    }

    func user(for token: String) -> User? {
        guard let email = tokens[token], let user = accounts[email] else { return nil }
        return user
    }

    private func createUser(email: String, displayName: String, city: String) -> User {
        User(
            id: UUID().uuidString,
            displayName: displayName,
            avatarUrl: nil,
            city: city,
            createdAtUtc: Date()
        )
    }
}
