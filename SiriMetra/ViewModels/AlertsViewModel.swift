import Foundation

@MainActor
final class AlertsViewModel: ObservableObject {
    @Published var alerts: [ServiceAlert] = []
    @Published var isLoading = false

    private let engine = ScheduleEngine.shared

    func refresh() async {
        isLoading = true
        do {
            try await engine.refreshData()
            alerts = await engine.getActiveAlerts()
        } catch {
            alerts = []
        }
        isLoading = false
    }
}
