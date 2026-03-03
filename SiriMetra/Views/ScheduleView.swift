import SwiftUI

/// Shows upcoming trains for the user's commute.
struct ScheduleView: View {
    @EnvironmentObject var preferencesStore: PreferencesStore
    @StateObject private var viewModel = ScheduleViewModel()
    @State private var direction: TrainDirection = .toWork

    enum TrainDirection: String, CaseIterable {
        case toWork = "To Work"
        case toHome = "To Home"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Direction picker
                Picker("Direction", selection: $direction) {
                    ForEach(TrainDirection.allCases, id: \.self) { dir in
                        Text(dir.rawValue).tag(dir)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Train list
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading schedule...")
                    Spacer()
                } else if viewModel.trains.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "tram.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No upcoming trains")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Check your station settings or try a different direction.")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
                    List(viewModel.trains, id: \.trip.id) { result in
                        trainRow(result)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Schedule")
            .onChange(of: direction) { _, _ in
                Task {
                    await loadTrains()
                }
            }
            .refreshable {
                await loadTrains()
            }
            .task {
                await loadTrains()
            }
        }
    }

    private func trainRow(_ result: ScheduleEngine.NextTrainResult) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if let route = result.route {
                        Text(route.shortName)
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(route.color.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    Text(result.trip.tripHeadsign)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("\(result.fromStation.name) → \(result.toStation.name)")
                    .font(.body)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(result.adjustedDepartureTime, style: .time)
                    .font(.headline)

                if let delay = result.delayMinutes, delay > 0 {
                    Text("+\(delay) min")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fontWeight(.semibold)
                } else {
                    Text("On time")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func loadTrains() async {
        let prefs = preferencesStore.preferences
        let fromID: String?
        let toID: String?

        switch direction {
        case .toWork:
            fromID = prefs.homeStationID
            toID = prefs.workStationID
        case .toHome:
            fromID = prefs.workStationID
            toID = prefs.homeStationID
        }

        guard let from = fromID, let to = toID else { return }
        await viewModel.loadUpcomingTrains(fromStationID: from, toStationID: to)
    }
}
