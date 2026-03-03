import Foundation

/// User preferences stored exclusively on-device. Never transmitted externally.
struct UserPreferences: Codable {
    var homeStationID: String?
    var workStationID: String?
    var preferredRouteIDs: [String]
    var notificationsEnabled: Bool
    var notifyOnDelays: Bool
    var notifyOnAlerts: Bool
    var delayThresholdMinutes: Int  // Only notify if delay >= this
    var hasCompletedOnboarding: Bool
    var gdprConsentGranted: Bool
    var gdprConsentDate: Date?
    var dataRetentionDays: Int

    static let `default` = UserPreferences(
        homeStationID: nil,
        workStationID: nil,
        preferredRouteIDs: [],
        notificationsEnabled: false,
        notifyOnDelays: true,
        notifyOnAlerts: true,
        delayThresholdMinutes: 5,
        hasCompletedOnboarding: false,
        gdprConsentGranted: false,
        gdprConsentDate: nil,
        dataRetentionDays: 30
    )
}

/// On-device storage for user preferences. No cloud sync, no analytics.
final class PreferencesStore: ObservableObject {
    @Published var preferences: UserPreferences {
        didSet { save() }
    }

    private static let storageKey = "com.sirimetra.userPreferences"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            self.preferences = decoded
        } else {
            self.preferences = .default
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    /// GDPR: Export all stored user data as JSON.
    func exportUserData() -> Data? {
        try? JSONEncoder().encode(preferences)
    }

    /// GDPR: Delete all user data and reset to defaults.
    func deleteAllUserData() {
        preferences = .default
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }
}
