import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var routes: [Route] = []
    @Published var homeStationName: String?
    @Published var workStationName: String?
    @Published var selectedRouteID: String?
    @Published var selectedHomeID: String?
    @Published var selectedWorkID: String?
    @Published var selectedRouteName: String?

    private let gtfs = GTFSDataManager.shared
    private let engine = ScheduleEngine.shared

    func load(preferences: UserPreferences) async {
        // Load static data (from cache or download)
        do {
            try await gtfs.loadData()
            routes = await gtfs.routes.sorted { $0.longName < $1.longName }
        } catch {
            routes = []
        }

        selectedRouteID = preferences.selectedRouteID
        selectedHomeID = preferences.homeStationID
        selectedWorkID = preferences.workStationID
        homeStationName = await engine.stationName(for: preferences.homeStationID ?? "")
        workStationName = await engine.stationName(for: preferences.workStationID ?? "")
        selectedRouteName = routes.first(where: { $0.id == selectedRouteID })?.longName
    }
}
