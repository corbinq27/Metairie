import Foundation

/// A scheduled Metra trip (one train run from origin to destination).
struct Trip: Codable, Identifiable, Hashable {
    let id: String              // GTFS trip_id
    let routeID: String         // Which line
    let serviceID: String       // Weekday/weekend/holiday schedule
    let directionID: Int        // 0 = inbound (to Chicago), 1 = outbound
    let tripHeadsign: String    // e.g., "Chicago Union Station"
    let stopTimes: [StopTime]

    /// Whether this trip runs toward downtown Chicago.
    var isInbound: Bool { directionID == 0 }
}

/// A single stop within a trip.
struct StopTime: Codable, Hashable {
    let stopID: String          // Station ID
    let arrivalTime: String     // HH:MM:SS (can exceed 24:00 for overnight)
    let departureTime: String   // HH:MM:SS
    let stopSequence: Int

    /// Parse the GTFS time string into today's Date.
    /// GTFS times can exceed 24:00:00 for trips past midnight.
    func arrivalDate(on date: Date = .now) -> Date? {
        Self.parseGTFSTime(arrivalTime, on: date)
    }

    func departureDate(on date: Date = .now) -> Date? {
        Self.parseGTFSTime(departureTime, on: date)
    }

    private static func parseGTFSTime(_ timeString: String, on date: Date) -> Date? {
        let parts = timeString.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let hours = parts[0]
        let minutes = parts[1]
        let seconds = parts[2]
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(
            byAdding: .second,
            value: hours * 3600 + minutes * 60 + seconds,
            to: startOfDay
        )
    }
}

/// Real-time position/status update for a trip.
struct TripUpdate: Codable, Identifiable {
    let id: String              // trip_id
    let routeID: String
    let delay: Int?             // Delay in seconds (positive = late)
    let stopTimeUpdates: [StopTimeUpdate]
    let timestamp: Date

    var delayMinutes: Int? {
        guard let delay else { return nil }
        return delay / 60
    }
}

struct StopTimeUpdate: Codable {
    let stopID: String
    let arrivalDelay: Int?      // Seconds
    let departureDelay: Int?    // Seconds
}
