import Foundation

actor ApiClient {
    static let shared = ApiClient()

    private let baseURL = URL(string: "http://localhost:5000/api")!
    private var token: String?
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
        let payload = ["email": email, "password": password]
        let data = try await request(path: "auth/login", method: "POST", body: payload)
        return try decoder.decode(AuthResponse.self, from: data)
    }

    func register(email: String, password: String, displayName: String, city: String) async throws -> AuthResponse {
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
        let data = try await request(path: "categories")
        return try decoder.decode([EventCategory].self, from: data)
    }

    func fetchNearbyEvents(lat: Double, lng: Double, radiusKm: Double) async throws -> [Event] {
        let query = [
            URLQueryItem(name: "lat", value: String(lat)),
            URLQueryItem(name: "lng", value: String(lng)),
            URLQueryItem(name: "radiusKm", value: String(radiusKm))
        ]
        let data = try await request(path: "events/near", queryItems: query)
        return try decoder.decode([Event].self, from: data)
    }

    func fetchEventDetail(id: String) async throws -> Event {
        let data = try await request(path: "events/\(id)")
        return try decoder.decode(Event.self, from: data)
    }

    func createEvent(_ requestBody: CreateEventRequest) async throws -> Event {
        let data = try await request(path: "events", method: "POST", body: requestBody, authorized: true)
        return try decoder.decode(Event.self, from: data)
    }

    func fetchEventAttendance(eventId: String) async throws -> [EventAttendance] {
        let data = try await request(path: "events/\(eventId)/attendance")
        return try decoder.decode([EventAttendance].self, from: data)
    }

    func setAttendance(eventId: String, status: AttendanceStatus) async throws -> EventAttendance {
        let payload = ["status": status.rawValue]
        let data = try await request(path: "events/\(eventId)/attendance", method: "POST", body: payload, authorized: true)
        return try decoder.decode(EventAttendance.self, from: data)
    }

    func fetchMyEvents() async throws -> [Event] {
        let data = try await request(path: "me/events", authorized: true)
        return try decoder.decode([Event].self, from: data)
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
