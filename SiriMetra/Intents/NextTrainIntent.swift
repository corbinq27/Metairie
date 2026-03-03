import AppIntents
import Foundation

/// Siri App Intent: "When is the next train to home?" / "When is the next train to work?"
///
/// This intent is invoked by Siri and answers with the next train departure time.
/// If home/work stations are not configured, the user is directed to the app.
struct NextTrainIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Train"
    static var description = IntentDescription(
        "Find the next Metra train to your home or work station.",
        categoryName: "Transit"
    )

    /// Whether the user is asking about the train to home or to work.
    @Parameter(title: "Destination")
    var destination: TrainDestination

    static var parameterSummary: some ParameterSummary {
        Summary("Next train to \(\.$destination)")
    }

    /// Siri phrases that trigger this intent.
    static var openAppWhenRun: Bool = false

    @Dependency
    private var scheduleEngine: ScheduleEngine

    @Dependency
    private var notificationManager: NotificationManager

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let store = PreferencesStore()
        let prefs = store.preferences

        // Check if onboarding is complete
        guard prefs.hasCompletedOnboarding else {
            return .result(
                dialog: "Please open SiriMetra to set up your home and work stations first."
            ) {
                NeedsSetupSnippetView()
            }
        }

        let fromID: String?
        let toID: String?

        switch destination {
        case .home:
            // Going home = from work station to home station
            fromID = prefs.workStationID
            toID = prefs.homeStationID
        case .work:
            // Going to work = from home station to work station
            fromID = prefs.homeStationID
            toID = prefs.workStationID
        }

        guard let fromStationID = fromID, let toStationID = toID else {
            return .result(
                dialog: "Please set your \(destination == .home ? "work" : "home") station in SiriMetra first."
            ) {
                NeedsSetupSnippetView()
            }
        }

        // Refresh data and find next train
        do {
            try await scheduleEngine.refreshData()
            guard let result = try await scheduleEngine.nextTrain(
                fromStationID: fromStationID,
                toStationID: toStationID
            ) else {
                return .result(
                    dialog: "No upcoming trains found for this route today."
                ) {
                    NoTrainsSnippetView()
                }
            }

            // Send a push notification with the info
            await notificationManager.sendNextTrainNotification(result: result)

            return .result(dialog: "\(result.summary)") {
                NextTrainSnippetView(result: result)
            }
        } catch {
            return .result(
                dialog: "I couldn't fetch the latest schedule. Please check your connection."
            ) {
                ErrorSnippetView()
            }
        }
    }
}

// MARK: - Destination Enum

enum TrainDestination: String, AppEnum {
    case home
    case work

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Destination"

    static var caseDisplayRepresentations: [TrainDestination: DisplayRepresentation] = [
        .home: "Home",
        .work: "Work"
    ]
}

// MARK: - Siri Shortcut Phrases

struct SiriMetraShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextTrainIntent(),
            phrases: [
                "When is the next train to \(\.$destination) on \(.applicationName)",
                "Next \(.applicationName) train to \(\.$destination)",
                "\(.applicationName) next train \(\.$destination)",
                "When does my train \(\.$destination) leave on \(.applicationName)"
            ],
            shortTitle: "Next Train",
            systemImageName: "tram.fill"
        )
    }
}

// MARK: - Snippet Views for Siri

import SwiftUI

struct NextTrainSnippetView: View {
    let result: ScheduleEngine.NextTrainResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "tram.fill")
                    .foregroundStyle(.blue)
                Text(result.route?.shortName ?? "Metra")
                    .font(.headline)
            }

            Text("\(result.fromStation.name) → \(result.toStation.name)")
                .font(.subheadline)

            HStack {
                Text("Departs:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(result.adjustedDepartureTime, style: .time)
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            if let delay = result.delayMinutes, delay > 0 {
                Label("\(delay) min late", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if !result.activeAlerts.isEmpty {
                Label(
                    "\(result.activeAlerts.count) alert(s)",
                    systemImage: "exclamationmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(.red)
            }
        }
        .padding()
    }
}

struct NeedsSetupSnippetView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "gear")
                .font(.largeTitle)
                .foregroundStyle(.blue)
            Text("Open SiriMetra to set up your stations")
                .font(.subheadline)
        }
        .padding()
    }
}

struct NoTrainsSnippetView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tram.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No upcoming trains found")
                .font(.subheadline)
        }
        .padding()
    }
}

struct ErrorSnippetView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text("Connection issue")
                .font(.subheadline)
        }
        .padding()
    }
}
