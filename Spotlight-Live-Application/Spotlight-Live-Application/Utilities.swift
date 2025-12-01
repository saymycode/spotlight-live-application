import Foundation
import SwiftUI
import CoreLocation

extension Color {
    init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }
        var int: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexString.count {
        case 8:
            (a, r, g, b) = (int >> 24, (int >> 16) & 0xff, (int >> 8) & 0xff, int & 0xff)
        case 6:
            (a, r, g, b) = (255, int >> 16, (int >> 8) & 0xff, int & 0xff)
        default:
            return nil
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

extension Date {
    func formattedRange(to end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "tr_TR")
        return "\(formatter.string(from: self)) - \(formatter.string(from: end))"
    }
}

enum DistanceCalculator {
    static func distanceKm(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return loc1.distance(from: loc2) / 1000
    }
}

extension Event {
    var startDate: Date { startTimeUtc }
    var endDate: Date { endTimeUtc }
}

extension EventAttendance {
    static func counts(for attendances: [EventAttendance]) -> (going: Int, maybe: Int) {
        let going = attendances.filter { $0.status == .going }.count
        let maybe = attendances.filter { $0.status == .maybe }.count
        return (going, maybe)
    }
}
