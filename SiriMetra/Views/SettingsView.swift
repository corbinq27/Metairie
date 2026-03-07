import SwiftUI

/// Settings screen for station preferences, notifications, and privacy.
struct SettingsView: View {
    @EnvironmentObject var preferencesStore: PreferencesStore
    @EnvironmentObject var gdprManager: GDPRManager
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showPrivacyDashboard = false
    @State private var showStationPicker: StationPickerTarget?

    enum StationPickerTarget: Identifiable {
        case home, work
        var id: String { "\(self)" }
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Line & Stations
                Section("Your Commute") {
                    HStack {
                        Label("Metra Line", systemImage: "train.side.front.car")
                        Spacer()
                        Text(viewModel.selectedRouteName ?? "Not set")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showStationPicker = .home
                    } label: {
                        HStack {
                            Label("Home Station", systemImage: "house.fill")
                            Spacer()
                            Text(viewModel.homeStationName ?? "Not set")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        showStationPicker = .work
                    } label: {
                        HStack {
                            Label("Work Station", systemImage: "building.2.fill")
                            Spacer()
                            Text(viewModel.workStationName ?? "Not set")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // MARK: - Notifications
                Section("Notifications") {
                    Toggle(isOn: $preferencesStore.preferences.notificationsEnabled) {
                        Label("Enable Notifications", systemImage: "bell.fill")
                    }

                    if preferencesStore.preferences.notificationsEnabled {
                        Toggle(isOn: $preferencesStore.preferences.notifyOnDelays) {
                            Label("Delay Alerts", systemImage: "clock.badge.exclamationmark")
                        }

                        Toggle(isOn: $preferencesStore.preferences.notifyOnAlerts) {
                            Label("Service Alerts", systemImage: "exclamationmark.triangle")
                        }

                        Stepper(
                            value: $preferencesStore.preferences.delayThresholdMinutes,
                            in: 1...30
                        ) {
                            Label(
                                "Notify if delay >= \(preferencesStore.preferences.delayThresholdMinutes) min",
                                systemImage: "timer"
                            )
                        }
                    }
                }

                // MARK: - Realtime Data
                Section {
                    SecureField("Metra API Key", text: Binding(
                        get: { preferencesStore.preferences.metraAPIKey ?? "" },
                        set: { preferencesStore.preferences.metraAPIKey = $0.isEmpty ? nil : $0 }
                    ))
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                } header: {
                    Text("Realtime Data")
                } footer: {
                    Text("Optional. Get a free API key from metra.com/metra-gtfs-api to see live delays and alerts.")
                }

                // MARK: - Siri
                Section("Siri") {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Voice Commands")
                                .font(.body)
                            Text("\"When is the next train to home?\"")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .italic()
                        }
                    } icon: {
                        Image(systemName: "mic.fill")
                    }
                }

                // MARK: - Privacy
                Section("Privacy & Data") {
                    Button {
                        showPrivacyDashboard = true
                    } label: {
                        Label("Privacy Dashboard", systemImage: "hand.raised.fill")
                    }

                    Label {
                        VStack(alignment: .leading) {
                            Text("Data Storage")
                            Text("All data stored on-device only")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "lock.shield.fill")
                    }
                }

                // MARK: - About
                Section("About") {
                    Label("Version 1.0.0", systemImage: "info.circle")
                    Label {
                        Text("Metra is a registered trademark of the Northeast Illinois Regional Commuter Railroad Corporation.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "text.quote")
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(item: $showStationPicker) { target in
                NavigationStack {
                    StationPickerView(
                        routes: viewModel.routes,
                        selectedRouteID: $viewModel.selectedRouteID,
                        selectedStationID: target == .home
                            ? $viewModel.selectedHomeID
                            : $viewModel.selectedWorkID
                    )
                    .padding()
                    .navigationTitle(target == .home ? "Home Station" : "Work Station")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                preferencesStore.preferences.selectedRouteID = viewModel.selectedRouteID
                                if target == .home {
                                    preferencesStore.preferences.homeStationID = viewModel.selectedHomeID
                                } else {
                                    preferencesStore.preferences.workStationID = viewModel.selectedWorkID
                                }
                                showStationPicker = nil
                                // Refresh display names
                                Task { await viewModel.load(preferences: preferencesStore.preferences) }
                            }
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showStationPicker = nil
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showPrivacyDashboard) {
                PrivacyDashboardView()
            }
            .task {
                await viewModel.load(preferences: preferencesStore.preferences)
            }
        }
    }
}
