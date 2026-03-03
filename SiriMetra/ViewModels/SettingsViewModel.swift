import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var stations: [Station] = []
    @Published var homeStationName: String?
    @Published var workStationName: String?
    @Published var selectedHomeID: String?
    @Published var selectedWorkID: String?

    private let engine = ScheduleEngine.shared

    func load(preferences: UserPreferences) async {
        do {
            try await engine.refreshData()
            stations = await engine.getAllStations().sorted { $0.name < $1.name }
        } catch {
            stations = []
        }

        selectedHomeID = preferences.homeStationID
        selectedWorkID = preferences.workStationID
        homeStationName = await engine.stationName(for: preferences.homeStationID ?? "")
        workStationName = await engine.stationName(for: preferences.workStationID ?? "")
    }
}
