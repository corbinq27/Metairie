import Foundation
import WidgetKit

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var nextTrainHome: ScheduleEngine.NextTrainResult?
    @Published var nextTrainWork: ScheduleEngine.NextTrainResult?
    @Published var activeAlerts: [ServiceAlert] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isScheduleLoaded = false

    private let engine = ScheduleEngine.shared
    private let widgetDefaults = UserDefaults(suiteName: "group.com.sirimetra.app")

    func refresh(preferences: UserPreferences) async {
        isLoading = true
        errorMessage = nil

        do {
            try await engine.refreshData()
            isScheduleLoaded = await engine.isDataLoaded()

            // Next train home (from work → home)
            if let workID = preferences.workStationID,
               let homeID = preferences.homeStationID {
                nextTrainHome = try await engine.nextTrain(
                    fromStationID: workID,
                    toStationID: homeID,
                    routeID: preferences.selectedRouteID
                )
            }

            // Next train to work (from home → work)
            if let homeID = preferences.homeStationID,
               let workID = preferences.workStationID {
                nextTrainWork = try await engine.nextTrain(
                    fromStationID: homeID,
                    toStationID: workID,
                    routeID: preferences.selectedRouteID
                )
            }

            activeAlerts = await engine.getActiveAlerts()

            // Push data to widgets via App Group
            updateWidgetData()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Widget Data

    private func updateWidgetData() {
        writeTrainData(nextTrainHome, key: "widget.homeTrainData")
        writeTrainData(nextTrainWork, key: "widget.workTrainData")

        if let homeName = nextTrainHome?.toStation.name {
            widgetDefaults?.set(homeName, forKey: "widget.homeStationName")
        }
        if let workName = nextTrainWork?.toStation.name {
            widgetDefaults?.set(workName, forKey: "widget.workStationName")
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    private func writeTrainData(_ result: ScheduleEngine.NextTrainResult?, key: String) {
        guard let result else {
            widgetDefaults?.removeObject(forKey: key)
            return
        }
        struct WidgetTrainData: Codable {
            let stationName: String
            let departureTime: Date
            let delayMinutes: Int?
            let routeShortName: String?
            let routeColorHex: String?
        }
        let data = WidgetTrainData(
            stationName: result.toStation.name,
            departureTime: result.departureTime,
            delayMinutes: result.delayMinutes,
            routeShortName: result.route?.shortName,
            routeColorHex: result.route?.colorHex
        )
        if let encoded = try? JSONEncoder().encode(data) {
            widgetDefaults?.set(encoded, forKey: key)
        }
    }
}
