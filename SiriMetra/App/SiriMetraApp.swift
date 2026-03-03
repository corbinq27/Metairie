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
                .onAppear {
                    // Register App Intents dependencies
                    AppDependencyManager.shared.add(dependency: ScheduleEngine.shared)
                    AppDependencyManager.shared.add(dependency: NotificationManager.shared)
                }
        }
    }
}
