import Foundation

extension Date {
    /// Minutes from now until this date. Negative if in the past.
    var minutesFromNow: Int {
        Int(timeIntervalSinceNow / 60)
    }

    /// A human-readable relative time string (e.g., "in 5 min", "2 min ago").
    var relativeString: String {
        let minutes = minutesFromNow
        if minutes > 0 {
            return "in \(minutes) min"
        } else if minutes == 0 {
            return "now"
        } else {
            return "\(abs(minutes)) min ago"
        }
    }
}
