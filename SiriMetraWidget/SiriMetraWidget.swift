import WidgetKit
import SwiftUI

// MARK: - Shared Data

/// Lightweight snapshot of next-train info passed from the main app via App Group UserDefaults.
struct TrainWidgetData: Codable {
    let stationName: String
    let departureTime: Date
    let delayMinutes: Int?
    let routeShortName: String?
    let routeColorHex: String?

    var adjustedDepartureTime: Date {
        guard let delayMinutes else { return departureTime }
        return departureTime.addingTimeInterval(TimeInterval(delayMinutes * 60))
    }

    static let placeholder = TrainWidgetData(
        stationName: "Station",
        departureTime: Date().addingTimeInterval(1800),
        delayMinutes: nil,
        routeShortName: "BNSF",
        routeColorHex: "1E90FF"
    )
}

/// Keys for the shared App Group UserDefaults.
private enum WidgetDataKeys {
    static let suiteName = "group.com.sirimetra.app"
    static let homeTrainData = "widget.homeTrainData"
    static let workTrainData = "widget.workTrainData"
    static let homeStationName = "widget.homeStationName"
    static let workStationName = "widget.workStationName"
}

// MARK: - Timeline Entry

struct TrainTimelineEntry: TimelineEntry {
    let date: Date
    let homeData: TrainWidgetData?
    let workData: TrainWidgetData?
    let homeStationName: String
    let workStationName: String

    static let placeholder = TrainTimelineEntry(
        date: .now,
        homeData: .placeholder,
        workData: .placeholder,
        homeStationName: "Home Station",
        workStationName: "Work Station"
    )
}

// MARK: - Timeline Provider

struct TrainTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrainTimelineEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (TrainTimelineEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrainTimelineEntry>) -> Void) {
        let entry = loadEntry()
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadEntry() -> TrainTimelineEntry {
        let defaults = UserDefaults(suiteName: WidgetDataKeys.suiteName)

        var homeData: TrainWidgetData?
        var workData: TrainWidgetData?

        if let data = defaults?.data(forKey: WidgetDataKeys.homeTrainData) {
            homeData = try? JSONDecoder().decode(TrainWidgetData.self, from: data)
        }
        if let data = defaults?.data(forKey: WidgetDataKeys.workTrainData) {
            workData = try? JSONDecoder().decode(TrainWidgetData.self, from: data)
        }

        let homeName = defaults?.string(forKey: WidgetDataKeys.homeStationName) ?? "Home"
        let workName = defaults?.string(forKey: WidgetDataKeys.workStationName) ?? "Work"

        return TrainTimelineEntry(
            date: .now,
            homeData: homeData,
            workData: workData,
            homeStationName: homeName,
            workStationName: workName
        )
    }
}

// MARK: - Compact Home Widget

struct HomeTrainWidget: Widget {
    let kind = "HomeTrainWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TrainTimelineProvider()) { entry in
            CompactTrainView(
                icon: "house.fill",
                label: "Home",
                data: entry.homeData,
                stationName: entry.homeStationName
            )
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Train Home")
        .description("Shows the next Metra train to your home station.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Compact Work Widget

struct WorkTrainWidget: Widget {
    let kind = "WorkTrainWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TrainTimelineProvider()) { entry in
            CompactTrainView(
                icon: "building.2.fill",
                label: "Work",
                data: entry.workData,
                stationName: entry.workStationName
            )
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Train to Work")
        .description("Shows the next Metra train to your work station.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Medium Widget (Home + Work)

struct CommuteWidget: Widget {
    let kind = "CommuteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TrainTimelineProvider()) { entry in
            MediumCommuteView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Commute Overview")
        .description("Shows next trains to both home and work stations.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Compact Train View (Small Widget)

struct CompactTrainView: View {
    let icon: String
    let label: String
    let data: TrainWidgetData?
    let stationName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            if let data {
                Text(data.adjustedDepartureTime, style: .time)
                    .font(.title2)
                    .fontWeight(.bold)
                    .minimumScaleFactor(0.8)

                Text(data.adjustedDepartureTime, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    if let delay = data.delayMinutes, delay > 0 {
                        Text("+\(delay)m")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    }
                    if let shortName = data.routeShortName {
                        Text(shortName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                    }
                }

                Text(stationName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Spacer(minLength: 0)
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Open app to refresh")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(4)
    }
}

// MARK: - Medium Commute View

struct MediumCommuteView: View {
    let entry: TrainTimelineEntry

    var body: some View {
        HStack(spacing: 0) {
            trainColumn(
                icon: "house.fill",
                label: "Home",
                data: entry.homeData,
                stationName: entry.homeStationName
            )

            Divider()
                .padding(.vertical, 8)

            trainColumn(
                icon: "building.2.fill",
                label: "Work",
                data: entry.workData,
                stationName: entry.workStationName
            )
        }
        .padding(4)
    }

    private func trainColumn(
        icon: String,
        label: String,
        data: TrainWidgetData?,
        stationName: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            if let data {
                Text(data.adjustedDepartureTime, style: .time)
                    .font(.title3)
                    .fontWeight(.bold)
                    .minimumScaleFactor(0.8)

                Text(data.adjustedDepartureTime, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                if let delay = data.delayMinutes, delay > 0 {
                    Text("+\(delay) min late")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .fontWeight(.semibold)
                }

                Text(stationName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let shortName = data.routeShortName {
                    Text(shortName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(Capsule())
                }
            } else {
                Spacer(minLength: 0)
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }
}

// MARK: - Widget Bundle

@main
struct SiriMetraWidgetBundle: WidgetBundle {
    var body: some Widget {
        HomeTrainWidget()
        WorkTrainWidget()
        CommuteWidget()
    }
}
