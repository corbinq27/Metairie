import Foundation
import CoreLocation

/// A Metra station on the Chicagoland commuter rail network.
struct Station: Codable, Identifiable, Hashable {
    let id: String          // GTFS stop_id
    let name: String        // Human-readable name
    let latitude: Double
    let longitude: Double
    let routeIDs: [String]  // Which Metra lines serve this station
    let wheelchairAccessible: Bool
    let zone: String?       // Fare zone

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Station, rhs: Station) -> Bool {
        lhs.id == rhs.id
    }
}
