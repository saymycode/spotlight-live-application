import Foundation
import MapKit
import SwiftUI

struct EventCategory: Identifiable, Codable, Hashable {
    let id: String
    let key: CategoryKey
    let name: String
    let colorHex: String

    var color: Color {
        Color(hex: colorHex) ?? key.defaultColor
    }
}

enum CategoryKey: String, Codable, CaseIterable {
    case culture
    case sports
    case lifestyle
    case night

    var displayName: String {
        switch self {
        case .culture: return "Culture"
        case .sports: return "Sports"
        case .lifestyle: return "Lifestyle"
        case .night: return "Night"
        }
    }

    var defaultColor: Color {
        switch self {
        case .culture: return .purple
        case .sports: return .blue
        case .lifestyle: return .orange
        case .night: return .red
        }
    }
}

struct Event: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let description: String
    let categoryKey: CategoryKey
    let latitude: Double
    let longitude: Double
    let startTimeUtc: Date
    let endTimeUtc: Date
    let createdAtUtc: Date
    let createdByUserId: String
    let isPublic: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct EventAttendance: Identifiable, Codable, Hashable {
    let id: String
    let eventId: String
    let userId: String
    let status: AttendanceStatus
    let createdAtUtc: Date
}

enum AttendanceStatus: String, Codable, CaseIterable {
    case going
    case maybe
    case notGoing

    var title: String {
        switch self {
        case .going: return "Katılıyorum"
        case .maybe: return "Kararsızım"
        case .notGoing: return "Katılmıyorum"
        }
    }
}

struct User: Identifiable, Codable, Hashable {
    let id: String
    let displayName: String
    let avatarUrl: String?
    let city: String
    let createdAtUtc: Date
}

struct AuthResponse: Codable {
    let token: String
    let user: User
}

struct EventFilters {
    var selectedCategories: Set<CategoryKey> = Set(CategoryKey.allCases)
    var radiusKm: Double = 10

    func allows(_ event: Event) -> Bool {
        selectedCategories.contains(event.categoryKey)
    }
}

extension EventCategory {
    static var sample: [EventCategory] {
        [CategoryKey.culture, .sports, .lifestyle, .night].map {
            EventCategory(id: UUID().uuidString, key: $0, name: $0.displayName, colorHex: "")
        }
    }
}
