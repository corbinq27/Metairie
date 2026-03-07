import SwiftUI
import AppIntents

@main
struct SiriMetraApp: App {
    @StateObject private var preferencesStore = PreferencesStore()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(preferencesStore)
                .environmentObject(GDPRManager(preferencesStore: preferencesStore))
                .task {
                    // Configure API token from stored preferences
                    if let key = preferencesStore.preferences.metraAPIKey {
                        await MetraAPIService.shared.setAPIToken(key)
                    }
                    // Register App Intents dependencies
                    AppDependencyManager.shared.add(dependency: ScheduleEngine.shared)
                    AppDependencyManager.shared.add(dependency: NotificationManager.shared)
                }
        }
    }
}
