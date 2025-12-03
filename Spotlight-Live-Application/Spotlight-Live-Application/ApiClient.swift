import Foundation
import MapKit

actor ApiClient {
    static let shared = ApiClient()

    private let firebase = FirebaseService.shared
    private var token: String?

    func setToken(_ token: String?) {
        self.token = token
        print("[ApiClient] setToken called. token.set=\(token != nil)")
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        print("[ApiClient] login called. email=\(email) pwdLen=\(password.count)")
        do {
            let response = try await firebase.login(email: email, password: password)
            token = response.token
            print("[ApiClient] login OK. user.id=\(response.user.id) token.len=\(response.token.count)")
            return response
        } catch {
            let nsError = error as NSError
            print("[ApiClient] login failed. domain=\(nsError.domain) code=\(nsError.code) info=\(nsError.userInfo)")
            throw error
        }
    }

    func register(email: String, password: String, displayName: String, city: String) async throws -> AuthResponse {
        print("[ApiClient] register called. email=\(email) pwdLen=\(password.count) displayName=\(displayName) city=\(city)")
        do {
            let response = try await firebase.register(email: email, password: password, displayName: displayName, city: city)
            token = response.token
            print("[ApiClient] register OK. user.id=\(response.user.id) token.len=\(response.token.count)")
            return response
        } catch {
            let nsError = error as NSError
            print("[ApiClient] register failed. domain=\(nsError.domain) code=\(nsError.code) info=\(nsError.userInfo)")
            throw error
        }
    }

    func restoreSession() async -> AuthResponse? {
        print("[ApiClient] restoreSession called.")
        if let session = await firebase.restoreSession() {
            token = session.token
            print("[ApiClient] restoreSession OK. user.id=\(session.user.id)")
            return session
        }
        print("[ApiClient] restoreSession: no session.")
        return nil
    }

    func fetchCategories() async throws -> [EventCategory] {
        print("[ApiClient] fetchCategories called.")
        do {
            let items = try await firebase.fetchCategories()
            print("[ApiClient] fetchCategories OK. count=\(items.count)")
            return items
        } catch {
            let nsError = error as NSError
            print("[ApiClient] fetchCategories failed. domain=\(nsError.domain) code=\(nsError.code) info=\(nsError.userInfo)")
            throw error
        }
    }

    func fetchNearbyEvents(lat: Double, lng: Double, radiusKm: Double) async throws -> [Event] {
        print("[ApiClient] fetchNearbyEvents called. lat=\(lat) lng=\(lng) radiusKm=\(radiusKm)")
        do {
            let items = try await firebase.fetchNearbyEvents(lat: lat, lng: lng, radiusKm: radiusKm)
            print("[ApiClient] fetchNearbyEvents OK. count=\(items.count)")
            return items
        } catch {
            let nsError = error as NSError
            print("[ApiClient] fetchNearbyEvents failed. domain=\(nsError.domain) code=\(nsError.code) info=\(nsError.userInfo)")
            throw error
        }
    }

    func fetchEventDetail(id: String) async throws -> Event {
        print("[ApiClient] fetchEventDetail called. id=\(id)")
        do {
            let event = try await firebase.fetchEventDetail(id: id)
            print("[ApiClient] fetchEventDetail OK.")
            return event
        } catch {
            let nsError = error as NSError
            print("[ApiClient] fetchEventDetail failed. domain=\(nsError.domain) code=\(nsError.code) info=\(nsError.userInfo)")
            throw error
        }
    }

    func createEvent(_ requestBody: CreateEventRequest, userId: String) async throws -> Event {
        print("[ApiClient] createEvent called. userId=\(userId) title=\(requestBody.title)")
        do {
            let event = try await firebase.createEvent(requestBody, userId: userId)
            print("[ApiClient] createEvent OK. id=\(event.id)")
            return event
        } catch {
            let nsError = error as NSError
            print("[ApiClient] createEvent failed. domain=\(nsError.domain) code=\(nsError.code) info=\(nsError.userInfo)")
            throw error
        }
    }

    func fetchEventAttendance(eventId: String) async throws -> [EventAttendance] {
        print("[ApiClient] fetchEventAttendance called. eventId=\(eventId)")
        do {
            let items = try await firebase.fetchAttendance(eventId: eventId)
            print("[ApiClient] fetchEventAttendance OK. count=\(items.count)")
            return items
        } catch {
            let nsError = error as NSError
            print("[ApiClient] fetchEventAttendance failed. domain=\(nsError.domain) code=\(nsError.code) info=\(nsError.userInfo)")
            throw error
        }
    }

    func setAttendance(eventId: String, status: AttendanceStatus, userId: String) async throws -> EventAttendance {
        print("[ApiClient] setAttendance called. eventId=\(eventId) status=\(status.rawValue) userId=\(userId)")
        do {
            let rec = try await firebase.setAttendance(eventId: eventId, status: status, userId: userId)
            print("[ApiClient] setAttendance OK. id=\(rec.id)")
            return rec
        } catch {
            let nsError = error as NSError
            print("[ApiClient] setAttendance failed. domain=\(nsError.domain) code=\(nsError.code) info=\(nsError.userInfo)")
            throw error
        }
    }

    func fetchMyEvents(userId: String) async throws -> [Event] {
        print("[ApiClient] fetchMyEvents called. userId=\(userId)")
        do {
            let items = try await firebase.fetchMyEvents(userId: userId)
            print("[ApiClient] fetchMyEvents OK. count=\(items.count)")
            return items
        } catch {
            let nsError = error as NSError
            print("[ApiClient] fetchMyEvents failed. domain=\(nsError.domain) code=\(nsError.code) info=\(nsError.userInfo)")
            throw error
        }
    }

    func restoreUserFromToken(_ token: String) async -> User? {
        print("[ApiClient] restoreUserFromToken called.")
        guard let session = await firebase.restoreSession() else {
            print("[ApiClient] restoreUserFromToken: no session.")
            return nil
        }
        print("[ApiClient] restoreUserFromToken OK. user.id=\(session.user.id)")
        return session.user
    }

    func logout() async {
        print("[ApiClient] logout called.")
        await firebase.logout()
        token = nil
        print("[ApiClient] logout OK. token cleared.")
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
