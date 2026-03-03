import Foundation

/// A Metra service alert (delays, disruptions, planned work).
struct ServiceAlert: Codable, Identifiable {
    let id: String
    let routeIDs: [String]
    let headerText: String
    let descriptionText: String
    let cause: AlertCause
    let effect: AlertEffect
    let activePeriods: [ActivePeriod]
    let url: URL?
    let updatedAt: Date

    struct ActivePeriod: Codable {
        let start: Date?
        let end: Date?
    }

    var isActive: Bool {
        let now = Date()
        return activePeriods.contains { period in
            let afterStart = period.start.map { now >= $0 } ?? true
            let beforeEnd = period.end.map { now <= $0 } ?? true
            return afterStart && beforeEnd
        }
    }
}

enum AlertCause: String, Codable {
    case unknownCause = "UNKNOWN_CAUSE"
    case technicalProblem = "TECHNICAL_PROBLEM"
    case accident = "ACCIDENT"
    case weather = "WEATHER"
    case construction = "CONSTRUCTION"
    case maintenance = "MAINTENANCE"
    case strike = "STRIKE"
    case other = "OTHER_CAUSE"
}

enum AlertEffect: String, Codable {
    case noService = "NO_SERVICE"
    case reducedService = "REDUCED_SERVICE"
    case significantDelays = "SIGNIFICANT_DELAYS"
    case detour = "DETOUR"
    case modifiedService = "MODIFIED_SERVICE"
    case stopMoved = "STOP_MOVED"
    case additionalService = "ADDITIONAL_SERVICE"
    case other = "OTHER_EFFECT"
    case unknownEffect = "UNKNOWN_EFFECT"
}
