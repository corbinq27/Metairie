import SwiftUI

/// Guides the user through setting up home/work stations.
struct OnboardingView: View {
    @EnvironmentObject var preferencesStore: PreferencesStore
    @StateObject private var viewModel = OnboardingViewModel()
    @State private var currentStep = 0

    var body: some View {
        NavigationStack {
            TabView(selection: $currentStep) {
                // Step 1: Welcome
                welcomeStep
                    .tag(0)

                // Step 2: Select home station
                stationPickerStep(
                    title: "Where is your home station?",
                    subtitle: "Select the Metra station closest to home",
                    icon: "house.fill",
                    selectedID: $viewModel.selectedHomeStationID
                )
                .tag(1)

                // Step 3: Select work station
                stationPickerStep(
                    title: "Where is your work station?",
                    subtitle: "Select the Metra station closest to work",
                    icon: "building.2.fill",
                    selectedID: $viewModel.selectedWorkStationID
                )
                .tag(2)

                // Step 4: Notifications
                notificationStep
                    .tag(3)

                // Step 5: Siri setup
                siriStep
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: currentStep)
        }
        .task {
            await viewModel.loadStations()
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

            StationPickerView(
                stations: viewModel.stations,
                selectedStationID: selectedID
            )

            nextButton {
                currentStep += 1
            }
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
                    currentStep = 4
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
                currentStep = 4
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
        preferencesStore.preferences.homeStationID = viewModel.selectedHomeStationID
        preferencesStore.preferences.workStationID = viewModel.selectedWorkStationID
        preferencesStore.preferences.notificationsEnabled = viewModel.notificationsEnabled
        preferencesStore.preferences.hasCompletedOnboarding = true
    }
}

// MARK: - ViewModel

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var stations: [Station] = []
    @Published var selectedHomeStationID: String?
    @Published var selectedWorkStationID: String?
    @Published var notificationsEnabled = false

    func loadStations() async {
        do {
            stations = try await MetraAPIService.shared.fetchStations()
                .sorted { $0.name < $1.name }
        } catch {
            // Stations will be empty; user sees an empty picker
        }
    }

    func requestNotifications() async {
        notificationsEnabled = await NotificationManager.shared.requestAuthorization()
    }
}
