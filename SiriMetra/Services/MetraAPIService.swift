import Foundation

/// Fetches real-time data from Metra's GTFS-RT public API.
/// Static schedule data is handled by GTFSDataManager (from the schedule ZIP).
/// No user data is ever sent in these requests.
actor MetraAPIService {
    static let shared = MetraAPIService()

    // Metra's public GTFS-RT API (new endpoint, replaces the decommissioned gtfsapi.metrarail.com)
    private let realtimeBaseURL = URL(string: "https://gtfspublic.metrarr.com/gtfs/public")!
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        self.session = URLSession(configuration: config)
    }

    // MARK: - Real-Time Data (GTFS-RT JSON)

    /// Fetch real-time trip updates (delays, cancellations).
    func fetchTripUpdates() async throws -> [TripUpdate] {
        let url = realtimeBaseURL.appendingPathComponent("tripupdates")
        let data = try await fetchData(from: url)
        let decoded = try JSONDecoder().decode([GTFSTripUpdate].self, from: data)
        return decoded.map { $0.toTripUpdate() }
    }

    /// Fetch current service alerts.
    func fetchAlerts() async throws -> [ServiceAlert] {
        let url = realtimeBaseURL.appendingPathComponent("alerts")
        let data = try await fetchData(from: url)
        let decoded = try JSONDecoder().decode([GTFSAlert].self, from: data)
        return decoded.map { $0.toServiceAlert() }
    }

    /// Fetch real-time vehicle positions.
    func fetchPositions() async throws -> [VehiclePosition] {
        let url = realtimeBaseURL.appendingPathComponent("positions")
        let data = try await fetchData(from: url)
        return try JSONDecoder().decode([VehiclePosition].self, from: data)
    }

    // MARK: - Private

    private func fetchData(from url: URL) async throws -> Data {
        let request = URLRequest(url: url)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MetraAPIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw MetraAPIError.invalidResponse
        }
        return data
    }
}

// MARK: - Errors

enum MetraAPIError: LocalizedError {
    case invalidResponse
    case decodingFailed
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from Metra API."
        case .decodingFailed: return "Failed to parse Metra data."
        case .networkUnavailable: return "Network unavailable. Please check your connection."
        }
    }
}

// MARK: - Vehicle Position

struct VehiclePosition: Codable, Identifiable {
    let id: String
    let tripID: String
    let routeID: String
    let latitude: Double
    let longitude: Double
    let bearing: Double?
    let speed: Double?
    let timestamp: Date
}

// MARK: - GTFS-RT JSON Mapping Types (Internal)

private struct GTFSTripUpdate: Codable {
    let id: String
    let trip_update: TripUpdatePayload?

    struct TripUpdatePayload: Codable {
        let trip: TripDescriptor
        let stop_time_update: [StopTimeUpdatePayload]?
        let timestamp: Double?
    }

    struct TripDescriptor: Codable {
        let trip_id: String
        let route_id: String?
    }

    struct StopTimeUpdatePayload: Codable {
        let stop_id: String?
        let arrival: TimeEvent?
        let departure: TimeEvent?
    }

    struct TimeEvent: Codable {
        let delay: Int?
    }

    func toTripUpdate() -> TripUpdate {
        let delay = trip_update?.stop_time_update?.first?.arrival?.delay
        let stopUpdates = trip_update?.stop_time_update?.compactMap { stu -> StopTimeUpdate? in
            guard let stopID = stu.stop_id else { return nil }
            return StopTimeUpdate(
                stopID: stopID,
                arrivalDelay: stu.arrival?.delay,
                departureDelay: stu.departure?.delay
            )
        } ?? []

        return TripUpdate(
            id: trip_update?.trip.trip_id ?? id,
            routeID: trip_update?.trip.route_id ?? "",
            delay: delay,
            stopTimeUpdates: stopUpdates,
            timestamp: Date(timeIntervalSince1970: trip_update?.timestamp ?? 0)
        )
    }
}

private struct GTFSAlert: Codable {
    let id: String
    let alert: AlertPayload?

    struct AlertPayload: Codable {
        let informed_entity: [InformedEntity]?
        let header_text: TranslatedString?
        let description_text: TranslatedString?
        let cause: String?
        let effect: String?
        let active_period: [ActivePeriodPayload]?
        let url: TranslatedString?
    }

    struct InformedEntity: Codable {
        let route_id: String?
    }

    struct TranslatedString: Codable {
        let translation: [Translation]?
    }

    struct Translation: Codable {
        let text: String
        let language: String?
    }

    struct ActivePeriodPayload: Codable {
        let start: Double?
        let end: Double?
    }

    func toServiceAlert() -> ServiceAlert {
        let routeIDs = alert?.informed_entity?.compactMap(\.route_id) ?? []
        let header = alert?.header_text?.translation?.first?.text ?? ""
        let description = alert?.description_text?.translation?.first?.text ?? ""
        let urlString = alert?.url?.translation?.first?.text
        let alertURL = urlString.flatMap { URL(string: $0) }
        let periods = alert?.active_period?.map {
            ServiceAlert.ActivePeriod(
                start: $0.start.map { Date(timeIntervalSince1970: $0) },
                end: $0.end.map { Date(timeIntervalSince1970: $0) }
            )
        } ?? []

        return ServiceAlert(
            id: id,
            routeIDs: routeIDs,
            headerText: header,
            descriptionText: description,
            cause: AlertCause(rawValue: alert?.cause ?? "") ?? .unknownCause,
            effect: AlertEffect(rawValue: alert?.effect ?? "") ?? .unknownEffect,
            activePeriods: periods,
            url: alertURL,
            updatedAt: Date()
        )
    }
}
