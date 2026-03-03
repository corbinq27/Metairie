import SwiftUI

/// Root view that routes between onboarding and the main tab interface.
struct ContentView: View {
    @EnvironmentObject var preferencesStore: PreferencesStore
    @EnvironmentObject var gdprManager: GDPRManager

    var body: some View {
        Group {
            if !preferencesStore.preferences.gdprConsentGranted {
                ConsentView()
            } else if !preferencesStore.preferences.hasCompletedOnboarding {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            ScheduleView()
                .tabItem {
                    Label("Schedule", systemImage: "clock.fill")
                }

            AlertsView()
                .tabItem {
                    Label("Alerts", systemImage: "exclamationmark.triangle.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
