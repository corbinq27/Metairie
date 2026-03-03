import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set ourselves as the notification delegate
        UNUserNotificationCenter.current().delegate = self

        // Register notification categories
        Task { @MainActor in
            NotificationManager.shared.registerCategories()
            await NotificationManager.shared.checkAuthorizationStatus()
        }

        return true
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Handle notification taps — open the relevant view in the app.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let type = userInfo["type"] as? String {
            switch type {
            case "nextTrain":
                // Deep link to schedule view
                NotificationCenter.default.post(
                    name: .openSchedule,
                    object: nil,
                    userInfo: userInfo
                )
            case "delay", "serviceAlert":
                // Deep link to alerts view
                NotificationCenter.default.post(
                    name: .openAlerts,
                    object: nil,
                    userInfo: userInfo
                )
            default:
                break
            }
        }

        completionHandler()
    }

    /// Show notifications even when app is in foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

// MARK: - Deep Link Notification Names

extension Notification.Name {
    static let openSchedule = Notification.Name("openSchedule")
    static let openAlerts = Notification.Name("openAlerts")
}
