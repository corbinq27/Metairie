import Foundation

/// Computes next-train answers using GTFS static schedule + real-time updates.
/// Static data comes from GTFSDataManager (downloaded GTFS ZIP).
/// Realtime data comes from MetraAPIService (requires API key).
/// All computation happens on-device. No user data leaves the device.
actor ScheduleEngine {
    static let shared = ScheduleEngine()

    private let gtfs = GTFSDataManager.shared
    private let api = MetraAPIService.shared

    private var tripUpdates: [String: TripUpdate] = [:]
    private var alerts: [ServiceAlert] = []
    private var lastRealtimeRefresh: Date?

    // MARK: - Data Loading

    /// Load static schedule data (from GTFS ZIP cache or download).
    func loadStaticData() async throws {
        try await gtfs.loadData()
    }

    /// Refresh realtime data (delays, alerts). Requires API key.
    func refreshRealtimeData() async {
        do {
            async let fetchedUpdates = api.fetchTripUpdates()
            async let fetchedAlerts = api.fetchAlerts()
            let (u, a) = try await (fetchedUpdates, fetchedAlerts)
            tripUpdates = Dictionary(u.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
            alerts = a
            lastRealtimeRefresh = Date()
        } catch {
            // Realtime data is optional — static schedule still works
        }
    }

    /// Full refresh: load static data + realtime updates.
    func refreshData() async throws {
        try await loadStaticData()
        await refreshRealtimeData()
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
        routeID: String? = nil,
        after date: Date = .now
    ) async throws -> NextTrainResult? {
        let allStations = await gtfs.stations
        let allRoutes = await gtfs.routes

        guard let fromStation = allStations.first(where: { $0.id == fromStationID }),
              let toStation = allStations.first(where: { $0.id == toStationID }) else {
            return nil
        }

        let routeIDs: [String]
        if let routeID {
            routeIDs = [routeID]
        } else {
            routeIDs = allRoutes.map(\.id)
        }

        let activeServiceIDs = await gtfs.activeServiceIDs(for: date)
        var bestResult: NextTrainResult?

        for rid in routeIDs {
            let trips = await gtfs.tripsForRoute(rid)

            for trip in trips where activeServiceIDs.contains(trip.serviceID) {
                guard let fromStop = trip.stopTimes.first(where: { $0.stopID == fromStationID }),
                      let toStop = trip.stopTimes.first(where: { $0.stopID == toStationID }),
                      fromStop.stopSequence < toStop.stopSequence,
                      let departure = fromStop.departureDate(on: date),
                      let arrival = toStop.arrivalDate(on: date),
                      departure > date else {
                    continue
                }

                let delay = tripUpdates[trip.id]?.delayMinutes
                let tripAlerts = alerts.filter { $0.isActive && $0.routeIDs.contains(rid) }
                let route = allRoutes.first(where: { $0.id == rid })

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
        routeID: String? = nil,
        count: Int = 5,
        after date: Date = .now
    ) async throws -> [NextTrainResult] {
        let allStations = await gtfs.stations
        let allRoutes = await gtfs.routes

        guard let fromStation = allStations.first(where: { $0.id == fromStationID }),
              let toStation = allStations.first(where: { $0.id == toStationID }) else {
            return []
        }

        let routeIDs: [String]
        if let routeID {
            routeIDs = [routeID]
        } else {
            routeIDs = allRoutes.map(\.id)
        }

        let activeServiceIDs = await gtfs.activeServiceIDs(for: date)
        var results: [NextTrainResult] = []

        for rid in routeIDs {
            let trips = await gtfs.tripsForRoute(rid)

            for trip in trips where activeServiceIDs.contains(trip.serviceID) {
                guard let fromStop = trip.stopTimes.first(where: { $0.stopID == fromStationID }),
                      let toStop = trip.stopTimes.first(where: { $0.stopID == toStationID }),
                      fromStop.stopSequence < toStop.stopSequence,
                      let departure = fromStop.departureDate(on: date),
                      let arrival = toStop.arrivalDate(on: date),
                      departure > date else {
                    continue
                }

                let delay = tripUpdates[trip.id]?.delayMinutes
                let tripAlerts = alerts.filter { $0.isActive && $0.routeIDs.contains(rid) }
                let route = allRoutes.first(where: { $0.id == rid })

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

    func getAllStations() async -> [Station] { await gtfs.stations }
    func getAllRoutes() async -> [Route] { await gtfs.routes }
    func getStationsForRoute(_ routeID: String) async -> [Station] {
        await gtfs.stationsForRoute(routeID)
    }
    func getActiveAlerts() -> [ServiceAlert] { alerts.filter(\.isActive) }
    func isDataLoaded() async -> Bool { await gtfs.isLoaded }

    func stationName(for id: String) async -> String? {
        await gtfs.stations.first(where: { $0.id == id })?.name
    }
}
