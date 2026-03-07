import SwiftUI

/// Displays active Metra service alerts.
struct AlertsView: View {
    @StateObject private var viewModel = AlertsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading alerts...")
                } else if !viewModel.hasRealtimeAccess {
                    VStack(spacing: 12) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("API Key Required")
                            .font(.headline)
                        Text("Add your free Metra API key in Settings to see live alerts and delay info.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else if viewModel.alerts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                        Text("No Active Alerts")
                            .font(.headline)
                        Text("All Metra lines are running normally.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List(viewModel.alerts) { alert in
                        alertRow(alert)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Alerts")
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.refresh()
            }
        }
    }

    private func alertRow(_ alert: ServiceAlert) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconForEffect(alert.effect))
                    .foregroundStyle(colorForEffect(alert.effect))
                Text(alert.headerText)
                    .font(.headline)
                    .lineLimit(2)
            }

            if !alert.routeIDs.isEmpty {
                HStack {
                    ForEach(alert.routeIDs, id: \.self) { routeID in
                        Text(routeID)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }

            Text(alert.descriptionText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(4)

            HStack {
                Text(causeLabel(alert.cause))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                if let url = alert.url {
                    Link("More Info", destination: url)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func iconForEffect(_ effect: AlertEffect) -> String {
        switch effect {
        case .noService: return "xmark.octagon.fill"
        case .reducedService: return "minus.circle.fill"
        case .significantDelays: return "clock.badge.exclamationmark.fill"
        case .detour: return "arrow.triangle.swap"
        case .modifiedService: return "arrow.triangle.2.circlepath"
        case .stopMoved: return "mappin.and.ellipse"
        case .additionalService: return "plus.circle.fill"
        case .other, .unknownEffect: return "exclamationmark.triangle.fill"
        }
    }

    private func colorForEffect(_ effect: AlertEffect) -> Color {
        switch effect {
        case .noService: return .red
        case .reducedService, .significantDelays: return .orange
        case .additionalService: return .green
        default: return .yellow
        }
    }

    private func causeLabel(_ cause: AlertCause) -> String {
        switch cause {
        case .weather: return "Weather"
        case .construction: return "Construction"
        case .maintenance: return "Maintenance"
        case .accident: return "Accident"
        case .technicalProblem: return "Technical"
        case .strike: return "Strike"
        case .other: return "Other"
        case .unknownCause: return ""
        }
    }
}
