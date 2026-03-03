import Foundation
import SwiftUI

/// Manages GDPR compliance for the app.
///
/// Privacy architecture:
/// - All user data is stored exclusively on-device (UserDefaults).
/// - No user data is transmitted to any server, ever.
/// - No analytics, tracking, or telemetry.
/// - No third-party SDKs that collect data.
/// - The only network requests are to Metra's public GTFS API for schedule data.
/// - Users can export and delete all their data at any time.
@MainActor
final class GDPRManager: ObservableObject {
    @Published var consentStatus: ConsentStatus = .notDetermined
    @Published var showConsentPrompt = false

    private let preferencesStore: PreferencesStore

    enum ConsentStatus {
        case notDetermined
        case granted
        case denied
    }

    init(preferencesStore: PreferencesStore) {
        self.preferencesStore = preferencesStore
        if preferencesStore.preferences.gdprConsentGranted {
            consentStatus = .granted
        }
    }

    // MARK: - Consent

    /// Record that the user has granted consent for local data storage.
    func grantConsent() {
        consentStatus = .granted
        preferencesStore.preferences.gdprConsentGranted = true
        preferencesStore.preferences.gdprConsentDate = Date()
    }

    /// Record that the user has denied or withdrawn consent.
    func withdrawConsent() {
        consentStatus = .denied
        preferencesStore.preferences.gdprConsentGranted = false
        preferencesStore.preferences.gdprConsentDate = nil
        // When consent is withdrawn, delete all stored preferences
        deleteAllData()
    }

    // MARK: - GDPR Rights (Articles 15-20)

    /// Article 15: Right of access. Export all user data as JSON.
    func exportAllData() -> UserDataExport {
        UserDataExport(
            exportDate: Date(),
            preferences: preferencesStore.preferences,
            dataCategories: dataCategories(),
            retentionPolicy: retentionPolicyDescription()
        )
    }

    /// Article 15: Export data as shareable JSON file.
    func exportDataAsJSON() -> Data? {
        let export = exportAllData()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(export)
    }

    /// Article 17: Right to erasure. Delete all user data.
    func deleteAllData() {
        preferencesStore.deleteAllUserData()
    }

    /// Article 20: Right to data portability.
    func portableDataURL() -> URL? {
        guard let jsonData = exportDataAsJSON() else { return nil }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SiriMetra_UserData_Export.json")
        try? jsonData.write(to: tempURL)
        return tempURL
    }

    // MARK: - Data Inventory

    /// Describe all categories of data we store.
    func dataCategories() -> [DataCategory] {
        [
            DataCategory(
                name: "Station Preferences",
                description: "Your selected home and work stations",
                purpose: "To answer 'next train' queries via Siri",
                storage: "On-device only (UserDefaults)",
                shared: false
            ),
            DataCategory(
                name: "Notification Settings",
                description: "Whether you want delay/alert notifications",
                purpose: "To send relevant push notifications locally",
                storage: "On-device only (UserDefaults)",
                shared: false
            ),
            DataCategory(
                name: "App Preferences",
                description: "Your preferred Metra lines and display settings",
                purpose: "To personalize the app experience",
                storage: "On-device only (UserDefaults)",
                shared: false
            ),
            DataCategory(
                name: "GDPR Consent Record",
                description: "Whether and when you granted consent",
                purpose: "Legal compliance with GDPR Article 7",
                storage: "On-device only (UserDefaults)",
                shared: false
            )
        ]
    }

    func retentionPolicyDescription() -> String {
        """
        All data is stored locally on your device only. \
        No data is ever sent to our servers or any third party. \
        Data is retained until you delete the app or explicitly \
        request deletion via the Privacy Dashboard. \
        You can export or delete your data at any time.
        """
    }
}

// MARK: - Data Export Types

struct UserDataExport: Codable {
    let exportDate: Date
    let preferences: UserPreferences
    let dataCategories: [DataCategory]
    let retentionPolicy: String
}

struct DataCategory: Codable, Identifiable {
    var id: String { name }
    let name: String
    let description: String
    let purpose: String
    let storage: String
    let shared: Bool
}
