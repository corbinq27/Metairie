import Foundation
import UserNotifications

/// Manages local push notifications for train delays and alerts.
///
/// Privacy notes:
/// - Uses only LOCAL notifications (no remote push server).
/// - No device token is sent to any server.
/// - No notification content is logged or transmitted.
@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false

    private let center = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            isAuthorized = granted
            return granted
        } catch {
            isAuthorized = false
            return false
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Train Notifications

    /// Send a notification with next-train information.
    func sendNextTrainNotification(result: ScheduleEngine.NextTrainResult) {
        let content = UNMutableNotificationContent()
        content.title = "Next Train"
        content.body = result.summary
        content.sound = .default
        content.categoryIdentifier = "NEXT_TRAIN"

        // Deep link into the app's schedule view
        content.userInfo = [
            "type": "nextTrain",
            "fromStation": result.fromStation.id,
            "toStation": result.toStation.id,
            "tripID": result.trip.id
        ]

        let request = UNNotificationRequest(
            identifier: "nextTrain-\(result.trip.id)",
            content: content,
            trigger: nil  // Deliver immediately
        )

        center.add(request)
    }

    /// Send a delay alert notification.
    func sendDelayNotification(
        routeName: String,
        delayMinutes: Int,
        stationName: String,
        tripID: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = "\(routeName) Delay"
        content.body = "\(delayMinutes) minute delay at \(stationName)"
        content.sound = .default
        content.categoryIdentifier = "DELAY_ALERT"
        content.userInfo = [
            "type": "delay",
            "tripID": tripID
        ]

        let request = UNNotificationRequest(
            identifier: "delay-\(tripID)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        center.add(request)
    }

    /// Send a service alert notification.
    func sendServiceAlertNotification(alert: ServiceAlert) {
        let content = UNMutableNotificationContent()
        content.title = "Metra Service Alert"
        content.body = alert.headerText
        content.sound = .default
        content.categoryIdentifier = "SERVICE_ALERT"
        content.userInfo = [
            "type": "serviceAlert",
            "alertID": alert.id
        ]

        if let url = alert.url {
            content.userInfo["url"] = url.absoluteString
        }

        let request = UNNotificationRequest(
            identifier: "alert-\(alert.id)",
            content: content,
            trigger: nil
        )

        center.add(request)
    }

    // MARK: - Notification Categories

    func registerCategories() {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_DETAILS",
            title: "View Details",
            options: [.foreground]
        )

        let nextTrainCategory = UNNotificationCategory(
            identifier: "NEXT_TRAIN",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )

        let delayCategory = UNNotificationCategory(
            identifier: "DELAY_ALERT",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )

        let alertCategory = UNNotificationCategory(
            identifier: "SERVICE_ALERT",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([
            nextTrainCategory, delayCategory, alertCategory
        ])
    }

    /// Remove all delivered notifications.
    func clearAllNotifications() {
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
    }
}
