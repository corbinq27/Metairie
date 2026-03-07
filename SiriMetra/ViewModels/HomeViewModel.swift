import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var nextTrainHome: ScheduleEngine.NextTrainResult?
    @Published var nextTrainWork: ScheduleEngine.NextTrainResult?
    @Published var activeAlerts: [ServiceAlert] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isScheduleLoaded = false

    private let engine = ScheduleEngine.shared

    func refresh(preferences: UserPreferences) async {
        isLoading = true
        errorMessage = nil

        // Set API key for realtime data
        if let key = preferences.metraAPIKey {
            await MetraAPIService.shared.setAPIToken(key)
        }

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
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
