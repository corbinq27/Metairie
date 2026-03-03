import Foundation

@MainActor
final class ScheduleViewModel: ObservableObject {
    @Published var trains: [ScheduleEngine.NextTrainResult] = []
    @Published var isLoading = false

    private let engine = ScheduleEngine.shared

    func loadUpcomingTrains(fromStationID: String, toStationID: String) async {
        isLoading = true
        do {
            try await engine.refreshData()
            trains = try await engine.upcomingTrains(
                fromStationID: fromStationID,
                toStationID: toStationID,
                count: 10
            )
        } catch {
            trains = []
        }
        isLoading = false
    }
}
