import Foundation

/// Downloads, parses, and caches Metra's static GTFS schedule data.
/// The GTFS ZIP is downloaded from schedules.metrarail.com and parsed on-device.
/// Parsed data is cached to disk for offline use and fast subsequent launches.
actor GTFSDataManager {
    static let shared = GTFSDataManager()

    private let scheduleURL = URL(string: "https://schedules.metrarail.com/gtfs/schedule.zip")!
    private let publishedURL = URL(string: "https://schedules.metrarail.com/gtfs/published.txt")!
    private let session: URLSession
    private let cacheDirectory: URL

    private(set) var routes: [Route] = []
    private(set) var stations: [Station] = []
    private(set) var stationsByRoute: [String: [Station]] = [:]
    private(set) var trips: [Trip] = []
    private(set) var tripsByRoute: [String: [Trip]] = [:]
    private(set) var calendarEntries: [CalendarEntry] = []
    private(set) var isLoaded = false

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        self.session = URLSession(configuration: config)

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = docs.appendingPathComponent("GTFSCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// Load data: try cache first, then download if needed.
    func loadData() async throws {
        // Try loading from cache first
        if loadFromCache() {
            isLoaded = true
            // Check for updates in background (don't block)
            Task { try? await checkForUpdates() }
            return
        }

        // No cache — must download
        try await downloadAndParse()
    }

    /// Force a fresh download of schedule data.
    func forceRefresh() async throws {
        try await downloadAndParse()
    }

    /// Get stations for a specific route, in stop-sequence order.
    func stationsForRoute(_ routeID: String) -> [Station] {
        stationsByRoute[routeID] ?? []
    }

    /// Get trips for a specific route.
    func tripsForRoute(_ routeID: String) -> [Trip] {
        tripsByRoute[routeID] ?? []
    }

    /// Find which service IDs are active for a given date.
    func activeServiceIDs(for date: Date) -> Set<String> {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)

        return Set(calendarEntries.compactMap { entry in
            let inRange = date >= entry.startDate && date <= entry.endDate
            guard inRange else { return nil }

            switch weekday {
            case 1: return entry.sunday ? entry.serviceID : nil
            case 2: return entry.monday ? entry.serviceID : nil
            case 3: return entry.tuesday ? entry.serviceID : nil
            case 4: return entry.wednesday ? entry.serviceID : nil
            case 5: return entry.thursday ? entry.serviceID : nil
            case 6: return entry.friday ? entry.serviceID : nil
            case 7: return entry.saturday ? entry.serviceID : nil
            default: return nil
            }
        })
    }

    // MARK: - Download & Parse

    private func downloadAndParse() async throws {
        let (data, response) = try await session.data(from: scheduleURL)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw GTFSError.downloadFailed
        }

        let entries = try ZIPReader.extract(from: data)
        let fileMap = Dictionary(entries.map { ($0.filename, $0.data) }, uniquingKeysWith: { _, b in b })

        guard let routesData = fileMap["routes.txt"],
              let stopsData = fileMap["stops.txt"] else {
            throw GTFSError.missingRequiredFiles
        }

        // Parse core files
        routes = parseRoutes(routesData)
        stations = parseStops(stopsData)

        // Parse trips and stop_times (these are larger)
        if let tripsData = fileMap["trips.txt"] {
            trips = parseTrips(tripsData)
        }

        var stopTimesMap: [String: [StopTime]] = [:]
        if let stopTimesData = fileMap["stop_times.txt"] {
            stopTimesMap = parseStopTimes(stopTimesData)
        }

        // Attach stop times to trips
        for i in trips.indices {
            if let times = stopTimesMap[trips[i].id] {
                trips[i] = Trip(
                    id: trips[i].id,
                    routeID: trips[i].routeID,
                    serviceID: trips[i].serviceID,
                    directionID: trips[i].directionID,
                    tripHeadsign: trips[i].tripHeadsign,
                    stopTimes: times.sorted { $0.stopSequence < $1.stopSequence }
                )
            }
        }

        // Parse calendar
        if let calendarData = fileMap["calendar.txt"] {
            calendarEntries = parseCalendar(calendarData)
        }

        // Build indices
        buildIndices()

        // Save to cache
        saveToCache()

        isLoaded = true
    }

    private func buildIndices() {
        // Index trips by route
        tripsByRoute = Dictionary(grouping: trips, by: \.routeID)

        // Index stations by route using trip stop sequences
        let stationByID = Dictionary(stations.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var routeStations: [String: [Station]] = [:]

        for (routeID, routeTrips) in tripsByRoute {
            // Use the first trip with the most stops as representative
            guard let representativeTrip = routeTrips.max(by: {
                $0.stopTimes.count < $1.stopTimes.count
            }) else { continue }

            var seen = Set<String>()
            let orderedStations = representativeTrip.stopTimes.compactMap { st -> Station? in
                guard !seen.contains(st.stopID), let station = stationByID[st.stopID] else {
                    return nil
                }
                seen.insert(st.stopID)
                return station
            }
            routeStations[routeID] = orderedStations
        }

        stationsByRoute = routeStations
    }

    // MARK: - CSV Parsing

    private func parseRoutes(_ data: Data) -> [Route] {
        let rows = parseCSV(data)
        guard let header = rows.first else { return [] }
        let idx = csvIndex(header)

        return rows.dropFirst().compactMap { row in
            guard let routeID = field(row, idx, "route_id"),
                  let shortName = field(row, idx, "route_short_name"),
                  let longName = field(row, idx, "route_long_name") else {
                return nil
            }
            let color = field(row, idx, "route_color") ?? "0078AE"
            return Route(id: routeID, shortName: shortName, longName: longName, colorHex: color)
        }
    }

    private func parseStops(_ data: Data) -> [Station] {
        let rows = parseCSV(data)
        guard let header = rows.first else { return [] }
        let idx = csvIndex(header)

        return rows.dropFirst().compactMap { row in
            guard let stopID = field(row, idx, "stop_id"),
                  let name = field(row, idx, "stop_name"),
                  let latStr = field(row, idx, "stop_lat"),
                  let lonStr = field(row, idx, "stop_lon"),
                  let lat = Double(latStr),
                  let lon = Double(lonStr) else {
                return nil
            }
            let wheelchair = field(row, idx, "wheelchair_boarding").flatMap(Int.init) ?? 0
            let zone = field(row, idx, "zone_id")
            return Station(
                id: stopID,
                name: name,
                latitude: lat,
                longitude: lon,
                routeIDs: [],
                wheelchairAccessible: wheelchair == 1,
                zone: zone
            )
        }
    }

    private func parseTrips(_ data: Data) -> [Trip] {
        let rows = parseCSV(data)
        guard let header = rows.first else { return [] }
        let idx = csvIndex(header)

        return rows.dropFirst().compactMap { row in
            guard let tripID = field(row, idx, "trip_id"),
                  let routeID = field(row, idx, "route_id"),
                  let serviceID = field(row, idx, "service_id") else {
                return nil
            }
            let direction = field(row, idx, "direction_id").flatMap(Int.init) ?? 0
            let headsign = field(row, idx, "trip_headsign") ?? ""
            return Trip(
                id: tripID,
                routeID: routeID,
                serviceID: serviceID,
                directionID: direction,
                tripHeadsign: headsign,
                stopTimes: []
            )
        }
    }

    private func parseStopTimes(_ data: Data) -> [String: [StopTime]] {
        let rows = parseCSV(data)
        guard let header = rows.first else { return [:] }
        let idx = csvIndex(header)

        var result: [String: [StopTime]] = [:]

        for row in rows.dropFirst() {
            guard let tripID = field(row, idx, "trip_id"),
                  let stopID = field(row, idx, "stop_id"),
                  let arrival = field(row, idx, "arrival_time"),
                  let departure = field(row, idx, "departure_time"),
                  let seqStr = field(row, idx, "stop_sequence"),
                  let seq = Int(seqStr) else {
                continue
            }
            let stopTime = StopTime(
                stopID: stopID,
                arrivalTime: arrival,
                departureTime: departure,
                stopSequence: seq
            )
            result[tripID, default: []].append(stopTime)
        }

        return result
    }

    private func parseCalendar(_ data: Data) -> [CalendarEntry] {
        let rows = parseCSV(data)
        guard let header = rows.first else { return [] }
        let idx = csvIndex(header)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"

        return rows.dropFirst().compactMap { row in
            guard let serviceID = field(row, idx, "service_id"),
                  let startStr = field(row, idx, "start_date"),
                  let endStr = field(row, idx, "end_date"),
                  let startDate = dateFormatter.date(from: startStr),
                  let endDate = dateFormatter.date(from: endStr) else {
                return nil
            }
            return CalendarEntry(
                serviceID: serviceID,
                monday: field(row, idx, "monday") == "1",
                tuesday: field(row, idx, "tuesday") == "1",
                wednesday: field(row, idx, "wednesday") == "1",
                thursday: field(row, idx, "thursday") == "1",
                friday: field(row, idx, "friday") == "1",
                saturday: field(row, idx, "saturday") == "1",
                sunday: field(row, idx, "sunday") == "1",
                startDate: startDate,
                endDate: endDate
            )
        }
    }

    /// Parse CSV data into rows of fields, handling quoted fields.
    private func parseCSV(_ data: Data) -> [[String]] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        var rows: [[String]] = []

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            var fields: [String] = []
            var current = ""
            var inQuotes = false

            for char in trimmed {
                if char == "\"" {
                    inQuotes.toggle()
                } else if char == "," && !inQuotes {
                    fields.append(current)
                    current = ""
                } else {
                    current.append(char)
                }
            }
            fields.append(current)
            rows.append(fields)
        }

        return rows
    }

    /// Build column-name → index mapping from CSV header row.
    private func csvIndex(_ header: [String]) -> [String: Int] {
        var result: [String: Int] = [:]
        for (i, col) in header.enumerated() {
            result[col.trimmingCharacters(in: .whitespacesAndNewlines)] = i
        }
        return result
    }

    /// Safely get a field from a CSV row by column name.
    private func field(_ row: [String], _ idx: [String: Int], _ name: String) -> String? {
        guard let i = idx[name], i < row.count else { return nil }
        let value = row[i].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    // MARK: - Cache

    private var cacheFile: URL { cacheDirectory.appendingPathComponent("gtfs_cache.json") }
    private var cacheTimestampFile: URL { cacheDirectory.appendingPathComponent("cache_timestamp.txt") }

    private func saveToCache() {
        let cache = GTFSCache(
            routes: routes,
            stations: stations,
            trips: trips,
            calendarEntries: calendarEntries
        )
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: cacheFile)
        try? Date().timeIntervalSince1970.description.write(to: cacheTimestampFile, atomically: true, encoding: .utf8)
    }

    private func loadFromCache() -> Bool {
        guard let data = try? Data(contentsOf: cacheFile),
              let cache = try? JSONDecoder().decode(GTFSCache.self, from: data) else {
            return false
        }

        routes = cache.routes
        stations = cache.stations
        trips = cache.trips
        calendarEntries = cache.calendarEntries
        buildIndices()
        return true
    }

    private func checkForUpdates() async throws {
        // Check when schedule was last published
        let (data, _) = try await session.data(from: publishedURL)
        guard let publishedText = String(data: data, encoding: .utf8) else { return }

        // Compare with our cache timestamp
        guard let cachedTimestampStr = try? String(contentsOf: cacheTimestampFile, encoding: .utf8),
              let cachedTimestamp = Double(cachedTimestampStr) else {
            // No cache timestamp — refresh
            try await downloadAndParse()
            return
        }

        // If published.txt content changed, refresh
        let currentHash = publishedText.hashValue
        let storedHashFile = cacheDirectory.appendingPathComponent("published_hash.txt")
        let storedHash = try? String(contentsOf: storedHashFile, encoding: .utf8)

        if storedHash != String(currentHash) {
            try? String(currentHash).write(to: storedHashFile, atomically: true, encoding: .utf8)
            // Schedule is newer than our cache
            let cacheAge = Date().timeIntervalSince1970 - cachedTimestamp
            if cacheAge > 3600 { // Only re-download if cache is > 1 hour old
                try await downloadAndParse()
            }
        }
    }
}

// MARK: - Calendar Entry

struct CalendarEntry: Codable {
    let serviceID: String
    let monday: Bool
    let tuesday: Bool
    let wednesday: Bool
    let thursday: Bool
    let friday: Bool
    let saturday: Bool
    let sunday: Bool
    let startDate: Date
    let endDate: Date
}

// MARK: - Cache Model

private struct GTFSCache: Codable {
    let routes: [Route]
    let stations: [Station]
    let trips: [Trip]
    let calendarEntries: [CalendarEntry]
}

// MARK: - Errors

enum GTFSError: LocalizedError {
    case downloadFailed
    case missingRequiredFiles
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .downloadFailed: return "Failed to download Metra schedule data."
        case .missingRequiredFiles: return "Schedule data is missing required files."
        case .parsingFailed: return "Failed to parse schedule data."
        }
    }
}
