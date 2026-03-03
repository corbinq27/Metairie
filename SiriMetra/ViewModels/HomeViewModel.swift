import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var nextTrainHome: ScheduleEngine.NextTrainResult?
    @Published var nextTrainWork: ScheduleEngine.NextTrainResult?
    @Published var activeAlerts: [ServiceAlert] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let engine = ScheduleEngine.shared

    func refresh(preferences: UserPreferences) async {
        isLoading = true
        errorMessage = nil

        do {
            try await engine.refreshData()

            // Next train home (from work → home)
            if let workID = preferences.workStationID,
               let homeID = preferences.homeStationID {
                nextTrainHome = try await engine.nextTrain(
                    fromStationID: workID,
                    toStationID: homeID
                )
            }

            // Next train to work (from home → work)
            if let homeID = preferences.homeStationID,
               let workID = preferences.workStationID {
                nextTrainWork = try await engine.nextTrain(
                    fromStationID: homeID,
                    toStationID: workID
                )
            }

            activeAlerts = await engine.getActiveAlerts()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
