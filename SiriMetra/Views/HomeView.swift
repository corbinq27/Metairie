import SwiftUI

/// Main home screen showing the next train and quick actions.
struct HomeView: View {
    @EnvironmentObject var preferencesStore: PreferencesStore
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Next train cards
                    if let homeResult = viewModel.nextTrainHome {
                        trainCard(
                            title: "Next Train Home",
                            icon: "house.fill",
                            result: homeResult
                        )
                    }

                    if let workResult = viewModel.nextTrainWork {
                        trainCard(
                            title: "Next Train to Work",
                            icon: "building.2.fill",
                            result: workResult
                        )
                    }

                    // Active alerts summary
                    if !viewModel.activeAlerts.isEmpty {
                        alertsSummaryCard
                    }

                    // Loading / empty states
                    if viewModel.isLoading {
                        ProgressView("Loading schedule...")
                            .padding()
                    }

                    if let error = viewModel.errorMessage {
                        errorCard(message: error)
                    }
                }
                .padding()
            }
            .navigationTitle("SiriMetra")
            .refreshable {
                await viewModel.refresh(preferences: preferencesStore.preferences)
            }
            .task {
                await viewModel.refresh(preferences: preferencesStore.preferences)
            }
        }
    }

    // MARK: - Cards

    private func trainCard(
        title: String,
        icon: String,
        result: ScheduleEngine.NextTrainResult
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.headline)
                Spacer()
                if let route = result.route {
                    Text(route.shortName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(route.color.opacity(0.2))
                        .clipShape(Capsule())
                }
            }

            HStack {
                VStack(alignment: .leading) {
                    Text(result.fromStation.name)
                        .font(.subheadline)
                    Text(result.toStation.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text(result.adjustedDepartureTime, style: .time)
                        .font(.title2)
                        .fontWeight(.bold)

                    if let delay = result.delayMinutes, delay > 0 {
                        Text("+\(delay) min")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fontWeight(.semibold)
                    }
                }
            }

            // Time until departure
            Text(result.adjustedDepartureTime, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !result.activeAlerts.isEmpty {
                Label(
                    "\(result.activeAlerts.count) alert(s) on this line",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var alertsSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                "\(viewModel.activeAlerts.count) Active Alert(s)",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.headline)
            .foregroundStyle(.orange)

            ForEach(viewModel.activeAlerts.prefix(3)) { alert in
                Text(alert.headerText)
                    .font(.caption)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func errorCard(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark")
                .font(.title)
                .foregroundStyle(.red)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
