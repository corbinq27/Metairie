import Foundation

/// Fetches real-time and static schedule data from Metra's GTFS API.
/// All network requests go only to Metra's official public API.
/// No user data is ever sent in these requests.
actor MetraAPIService {
    static let shared = MetraAPIService()

    // Metra's public GTFS API base URL
    private let baseURL = URL(string: "https://gtfsapi.metrarail.com/gtfs")!
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        // No cookies, no caching of user-identifying data
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        self.session = URLSession(configuration: config)
    }

    // MARK: - Static GTFS Data

    /// Fetch all Metra stations.
    func fetchStations() async throws -> [Station] {
        let url = baseURL.appendingPathComponent("schedule/stops")
        let data = try await fetchData(from: url)
        let gtfsStops = try JSONDecoder().decode([GTFSStop].self, from: data)
        return gtfsStops.compactMap { $0.toStation() }
    }

    /// Fetch all Metra routes/lines.
    func fetchRoutes() async throws -> [Route] {
        let url = baseURL.appendingPathComponent("schedule/routes")
        let data = try await fetchData(from: url)
        let gtfsRoutes = try JSONDecoder().decode([GTFSRoute].self, from: data)
        return gtfsRoutes.map { $0.toRoute() }
    }

    /// Fetch scheduled trips for a specific route.
    func fetchTrips(routeID: String) async throws -> [Trip] {
        let url = baseURL.appendingPathComponent("schedule/trips")
            .appending(queryItems: [URLQueryItem(name: "route_id", value: routeID)])
        let data = try await fetchData(from: url)
        let gtfsTrips = try JSONDecoder().decode([GTFSTrip].self, from: data)
        return gtfsTrips.map { $0.toTrip() }
    }

    /// Fetch stop times for a given trip.
    func fetchStopTimes(tripID: String) async throws -> [StopTime] {
        let url = baseURL.appendingPathComponent("schedule/stop_times")
            .appending(queryItems: [URLQueryItem(name: "trip_id", value: tripID)])
        let data = try await fetchData(from: url)
        return try JSONDecoder().decode([GTFSStopTime].self, from: data)
            .map { $0.toStopTime() }
    }

    // MARK: - Real-Time Data (GTFS-RT)

    /// Fetch real-time trip updates (delays, cancellations).
    func fetchTripUpdates() async throws -> [TripUpdate] {
        let url = baseURL.appendingPathComponent("tripUpdates")
        let data = try await fetchData(from: url)
        let decoded = try JSONDecoder().decode([GTFSTripUpdate].self, from: data)
        return decoded.map { $0.toTripUpdate() }
    }

    /// Fetch current service alerts.
    func fetchAlerts() async throws -> [ServiceAlert] {
        let url = baseURL.appendingPathComponent("alerts")
        let data = try await fetchData(from: url)
        let decoded = try JSONDecoder().decode([GTFSAlert].self, from: data)
        return decoded.map { $0.toServiceAlert() }
    }

    /// Fetch real-time vehicle positions.
    func fetchPositions() async throws -> [VehiclePosition] {
        let url = baseURL.appendingPathComponent("positions")
        let data = try await fetchData(from: url)
        return try JSONDecoder().decode([VehiclePosition].self, from: data)
    }

    // MARK: - Private

    private func fetchData(from url: URL) async throws -> Data {
        let request = URLRequest(url: url)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
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
        case .decodingFailed: return "Failed to parse Metra schedule data."
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

// MARK: - GTFS JSON Mapping Types (Internal)

private struct GTFSStop: Codable {
    let stop_id: String
    let stop_name: String
    let stop_lat: Double
    let stop_lon: Double
    let wheelchair_boarding: Int?
    let zone_id: String?

    func toStation() -> Station? {
        Station(
            id: stop_id,
            name: stop_name,
            latitude: stop_lat,
            longitude: stop_lon,
            routeIDs: [],  // Populated via route-stop mappings
            wheelchairAccessible: (wheelchair_boarding ?? 0) == 1,
            zone: zone_id
        )
    }
}

private struct GTFSRoute: Codable {
    let route_id: String
    let route_short_name: String
    let route_long_name: String
    let route_color: String?

    func toRoute() -> Route {
        Route(
            id: route_id,
            shortName: route_short_name,
            longName: route_long_name,
            colorHex: route_color ?? "0078AE"
        )
    }
}

private struct GTFSTrip: Codable {
    let trip_id: String
    let route_id: String
    let service_id: String
    let direction_id: Int
    let trip_headsign: String?

    func toTrip() -> Trip {
        Trip(
            id: trip_id,
            routeID: route_id,
            serviceID: service_id,
            directionID: direction_id,
            tripHeadsign: trip_headsign ?? "",
            stopTimes: []
        )
    }
}

private struct GTFSStopTime: Codable {
    let stop_id: String
    let arrival_time: String
    let departure_time: String
    let stop_sequence: Int

    func toStopTime() -> StopTime {
        StopTime(
            stopID: stop_id,
            arrivalTime: arrival_time,
            departureTime: departure_time,
            stopSequence: stop_sequence
        )
    }
}

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
