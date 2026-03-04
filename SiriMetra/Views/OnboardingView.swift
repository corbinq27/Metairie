import SwiftUI

/// Guides the user through setting up their Metra commute.
/// Flow: Welcome → Pick Line → Pick Home Station → Pick Work Station → Notifications → Siri
struct OnboardingView: View {
    @EnvironmentObject var preferencesStore: PreferencesStore
    @StateObject private var viewModel = OnboardingViewModel()
    @State private var currentStep = 0

    var body: some View {
        NavigationStack {
            TabView(selection: $currentStep) {
                // Step 0: Welcome
                welcomeStep
                    .tag(0)

                // Step 1: Select Metra line
                linePickerStep
                    .tag(1)

                // Step 2: Select home station (from selected line's stops)
                stationPickerStep(
                    title: "Where is your home station?",
                    subtitle: "Select the station closest to home",
                    icon: "house.fill",
                    selectedID: $viewModel.selectedHomeStationID
                )
                .tag(2)

                // Step 3: Select work station (from selected line's stops)
                stationPickerStep(
                    title: "Where is your work station?",
                    subtitle: "Select the station closest to work",
                    icon: "building.2.fill",
                    selectedID: $viewModel.selectedWorkStationID
                )
                .tag(3)

                // Step 4: Notifications
                notificationStep
                    .tag(4)

                // Step 5: Siri setup
                siriStep
                    .tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: currentStep)
        }
        .task {
            await viewModel.loadRoutes()
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "tram.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text("Let's Set Up SiriMetra")
                .font(.title)
                .fontWeight(.bold)

            Text("We'll configure your commute so Siri can tell you when the next train is.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
            nextButton { currentStep = 1 }
        }
        .padding()
    }

    private var linePickerStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "train.side.front.car")
                .font(.system(size: 40))
                .foregroundStyle(.blue)
                .padding(.top, 32)

            Text("Which Metra line do you ride?")
                .font(.title2)
                .fontWeight(.bold)

            Text("We'll show you stations on this line")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Metra Line")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Picker("Select a line", selection: $viewModel.selectedRouteID) {
                    Text("Choose a line…")
                        .tag(String?.none)
                    ForEach(viewModel.routes) { route in
                        Text(route.longName)
                            .tag(Optional(route.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(.primary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer()

            nextButton { currentStep = 2 }
                .disabled(viewModel.selectedRouteID == nil)
        }
        .padding()
        .onChange(of: viewModel.selectedRouteID) { _, newRouteID in
            // Clear station selections when line changes
            viewModel.selectedHomeStationID = nil
            viewModel.selectedWorkStationID = nil
            viewModel.stationsForRoute = []
            guard let routeID = newRouteID else { return }
            Task { await viewModel.loadStationsForRoute(routeID) }
        }
    }

    private func stationPickerStep(
        title: String,
        subtitle: String,
        icon: String,
        selectedID: Binding<String?>
    ) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.blue)
                .padding(.top, 32)

            Text(title)
                .font(.title2)
                .fontWeight(.bold)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                if let routeName = viewModel.selectedRouteName {
                    Text(routeName)
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .fontWeight(.medium)
                }

                if viewModel.isLoadingStations {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading stations…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Picker("Select a station", selection: selectedID) {
                        Text("Choose a station…")
                            .tag(String?.none)
                        ForEach(viewModel.stationsForRoute) { station in
                            Text(station.name)
                                .tag(Optional(station.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer()

            nextButton { currentStep += 1 }
                .disabled(selectedID.wrappedValue == nil)
        }
        .padding()
    }

    private var notificationStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Stay Informed")
                .font(.title2)
                .fontWeight(.bold)

            Text("Get notified about delays and service alerts for your commute.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task {
                    await viewModel.requestNotifications()
                    currentStep = 5
                }
            } label: {
                Text("Enable Notifications")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)

            Button("Skip") {
                currentStep = 5
            }
            .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
    }

    private var siriStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Ask Siri")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                siriPhrase("When is the next train to home?")
                siriPhrase("When is the next train to work?")
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()

            Button {
                completeOnboarding()
            } label: {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding()
    }

    // MARK: - Helpers

    private func nextButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Next")
                .frame(maxWidth: .infinity)
                .padding()
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 32)
    }

    private func siriPhrase(_ text: String) -> some View {
        HStack {
            Image(systemName: "mic.fill")
                .foregroundStyle(.blue)
            Text("\"\(text)\"")
                .font(.subheadline)
                .italic()
        }
    }

    private func completeOnboarding() {
        preferencesStore.preferences.selectedRouteID = viewModel.selectedRouteID
        preferencesStore.preferences.homeStationID = viewModel.selectedHomeStationID
        preferencesStore.preferences.workStationID = viewModel.selectedWorkStationID
        preferencesStore.preferences.notificationsEnabled = viewModel.notificationsEnabled
        preferencesStore.preferences.hasCompletedOnboarding = true
    }
}

// MARK: - ViewModel

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var routes: [Route] = []
    @Published var stationsForRoute: [Station] = []
    @Published var selectedRouteID: String?
    @Published var selectedHomeStationID: String?
    @Published var selectedWorkStationID: String?
    @Published var notificationsEnabled = false
    @Published var isLoadingStations = false

    var selectedRouteName: String? {
        routes.first(where: { $0.id == selectedRouteID })?.longName
    }

    func loadRoutes() async {
        do {
            routes = try await MetraAPIService.shared.fetchRoutes()
                .sorted { $0.longName < $1.longName }
        } catch {
            routes = []
        }
    }

    func loadStationsForRoute(_ routeID: String) async {
        isLoadingStations = true
        defer { isLoadingStations = false }
        do {
            stationsForRoute = try await MetraAPIService.shared.fetchStopsForRoute(routeID: routeID)
        } catch {
            stationsForRoute = []
        }
    }

    func requestNotifications() async {
        notificationsEnabled = await NotificationManager.shared.requestAuthorization()
    }
}
