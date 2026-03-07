import Foundation

@MainActor
final class AlertsViewModel: ObservableObject {
    @Published var alerts: [ServiceAlert] = []
    @Published var isLoading = false
    @Published var hasRealtimeAccess = false

    private let engine = ScheduleEngine.shared

    func refresh() async {
        isLoading = true
        hasRealtimeAccess = await MetraAPIService.shared.hasRealtimeAccess
        do {
            try await engine.loadStaticData()
            await engine.refreshRealtimeData()
            alerts = await engine.getActiveAlerts()
        } catch {
            alerts = []
        }
        isLoading = false
    }
}
