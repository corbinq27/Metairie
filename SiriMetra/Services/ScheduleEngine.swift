import Foundation

/// Computes next-train answers using cached schedule data and real-time updates.
/// All computation happens on-device. No user data leaves the device.
actor ScheduleEngine {
    static let shared = ScheduleEngine()

    private var stations: [Station] = []
    private var routes: [Route] = []
    private var tripsByRoute: [String: [Trip]] = [:]
    private var tripUpdates: [String: TripUpdate] = [:]
    private var alerts: [ServiceAlert] = []
    private var lastRefresh: Date?

    private let api = MetraAPIService.shared

    // MARK: - Data Loading

    /// Load or refresh all schedule data. Call on app launch and periodically.
    func refreshData() async throws {
        async let fetchedStations = api.fetchStations()
        async let fetchedRoutes = api.fetchRoutes()
        async let fetchedUpdates = api.fetchTripUpdates()
        async let fetchedAlerts = api.fetchAlerts()

        let (s, r, u, a) = try await (fetchedStations, fetchedRoutes, fetchedUpdates, fetchedAlerts)
        stations = s
        routes = r
        tripUpdates = Dictionary(u.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        alerts = a
        lastRefresh = Date()
    }

    /// Load trips for specific routes (lazy loading to save bandwidth).
    func loadTrips(forRouteIDs routeIDs: [String]) async throws {
        for routeID in routeIDs {
            if tripsByRoute[routeID] == nil {
                var trips = try await api.fetchTrips(routeID: routeID)
                // Load stop times for each trip
                for i in trips.indices {
                    let stopTimes = try await api.fetchStopTimes(tripID: trips[i].id)
                    trips[i] = Trip(
                        id: trips[i].id,
                        routeID: trips[i].routeID,
                        serviceID: trips[i].serviceID,
                        directionID: trips[i].directionID,
                        tripHeadsign: trips[i].tripHeadsign,
                        stopTimes: stopTimes
                    )
                }
                tripsByRoute[routeID] = trips
            }
        }
    }

    // MARK: - Next Train Query

    struct NextTrainResult {
        let trip: Trip
        let departureTime: Date
        let arrivalTime: Date
        let delayMinutes: Int?
        let fromStation: Station
        let toStation: Station
        let route: Route?
        let activeAlerts: [ServiceAlert]

        var adjustedDepartureTime: Date {
            guard let delayMinutes else { return departureTime }
            return departureTime.addingTimeInterval(TimeInterval(delayMinutes * 60))
        }

        var summary: String {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let timeStr = formatter.string(from: adjustedDepartureTime)
            var text = "Next train from \(fromStation.name) to \(toStation.name) departs at \(timeStr)"
            if let delay = delayMinutes, delay > 0 {
                text += " (\(delay) min late)"
            }
            if !activeAlerts.isEmpty {
                text += ". \(activeAlerts.count) active alert(s)."
            }
            return text
        }
    }

    /// Find the next train between two stations.
    func nextTrain(
        fromStationID: String,
        toStationID: String,
        after date: Date = .now
    ) async throws -> NextTrainResult? {
        guard let fromStation = stations.first(where: { $0.id == fromStationID }),
              let toStation = stations.first(where: { $0.id == toStationID }) else {
            return nil
        }

        // Determine which routes serve both stations
        let relevantRouteIDs = findCommonRoutes(
            fromStationID: fromStationID,
            toStationID: toStationID
        )

        // Ensure trips are loaded for these routes
        try await loadTrips(forRouteIDs: relevantRouteIDs)

        let serviceID = currentServiceID()
        var bestResult: NextTrainResult?

        for routeID in relevantRouteIDs {
            guard let trips = tripsByRoute[routeID] else { continue }

            for trip in trips where trip.serviceID == serviceID {
                guard let fromStop = trip.stopTimes.first(where: { $0.stopID == fromStationID }),
                      let toStop = trip.stopTimes.first(where: { $0.stopID == toStationID }),
                      fromStop.stopSequence < toStop.stopSequence,
                      let departure = fromStop.departureDate(on: date),
                      let arrival = toStop.arrivalDate(on: date),
                      departure > date else {
                    continue
                }

                let delay = tripUpdates[trip.id]?.delayMinutes
                let tripAlerts = alerts.filter {
                    $0.isActive && $0.routeIDs.contains(routeID)
                }
                let route = routes.first(where: { $0.id == routeID })

                let result = NextTrainResult(
                    trip: trip,
                    departureTime: departure,
                    arrivalTime: arrival,
                    delayMinutes: delay,
                    fromStation: fromStation,
                    toStation: toStation,
                    route: route,
                    activeAlerts: tripAlerts
                )

                if bestResult == nil || departure < bestResult!.departureTime {
                    bestResult = result
                }
            }
        }

        return bestResult
    }

    /// Find the next few trains (for schedule display).
    func upcomingTrains(
        fromStationID: String,
        toStationID: String,
        count: Int = 5,
        after date: Date = .now
    ) async throws -> [NextTrainResult] {
        guard let fromStation = stations.first(where: { $0.id == fromStationID }),
              let toStation = stations.first(where: { $0.id == toStationID }) else {
            return []
        }

        let relevantRouteIDs = findCommonRoutes(
            fromStationID: fromStationID,
            toStationID: toStationID
        )
        try await loadTrips(forRouteIDs: relevantRouteIDs)

        let serviceID = currentServiceID()
        var results: [NextTrainResult] = []

        for routeID in relevantRouteIDs {
            guard let trips = tripsByRoute[routeID] else { continue }

            for trip in trips where trip.serviceID == serviceID {
                guard let fromStop = trip.stopTimes.first(where: { $0.stopID == fromStationID }),
                      let toStop = trip.stopTimes.first(where: { $0.stopID == toStationID }),
                      fromStop.stopSequence < toStop.stopSequence,
                      let departure = fromStop.departureDate(on: date),
                      let arrival = toStop.arrivalDate(on: date),
                      departure > date else {
                    continue
                }

                let delay = tripUpdates[trip.id]?.delayMinutes
                let tripAlerts = alerts.filter {
                    $0.isActive && $0.routeIDs.contains(routeID)
                }
                let route = routes.first(where: { $0.id == routeID })

                results.append(NextTrainResult(
                    trip: trip,
                    departureTime: departure,
                    arrivalTime: arrival,
                    delayMinutes: delay,
                    fromStation: fromStation,
                    toStation: toStation,
                    route: route,
                    activeAlerts: tripAlerts
                ))
            }
        }

        return results
            .sorted { $0.departureTime < $1.departureTime }
            .prefix(count)
            .map { $0 }
    }

    // MARK: - Accessors

    func getAllStations() -> [Station] { stations }
    func getAllRoutes() -> [Route] { routes }
    func getActiveAlerts() -> [ServiceAlert] { alerts.filter(\.isActive) }

    func stationName(for id: String) -> String? {
        stations.first(where: { $0.id == id })?.name
    }

    // MARK: - Helpers

    private func findCommonRoutes(fromStationID: String, toStationID: String) -> [String] {
        // For initial implementation, return all route IDs.
        // A production version would cross-reference route-stop mappings.
        return routes.map(\.id)
    }

    /// Determine the GTFS service_id for today (weekday, saturday, sunday).
    private func currentServiceID() -> String {
        let weekday = Calendar.current.component(.weekday, from: Date())
        switch weekday {
        case 1: return "su"    // Sunday
        case 7: return "sa"    // Saturday
        default: return "wk"   // Weekday
        }
    }
}
