import SwiftUI

/// A two-step station picker: pick a Metra line first, then pick a station on that line.
/// Uses native Picker dropdowns — no search bar needed.
struct StationPickerView: View {
    let routes: [Route]
    @Binding var selectedRouteID: String?
    @Binding var selectedStationID: String?

    @State private var stationsForRoute: [Station] = []
    @State private var isLoadingStations = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Step 1: Pick a Metra line
            VStack(alignment: .leading, spacing: 6) {
                Text("Metra Line")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Picker("Select a line", selection: $selectedRouteID) {
                    Text("Choose a line…")
                        .tag(String?.none)
                    ForEach(routes) { route in
                        HStack {
                            Circle()
                                .fill(route.color)
                                .frame(width: 10, height: 10)
                            Text(route.longName)
                        }
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

            // Step 2: Pick a station (only shown after line is selected)
            if selectedRouteID != nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Station")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    if isLoadingStations {
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
                        Picker("Select a station", selection: $selectedStationID) {
                            Text("Choose a station…")
                                .tag(String?.none)
                            ForEach(stationsForRoute) { station in
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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer()
        }
        .animation(.easeInOut(duration: 0.25), value: selectedRouteID)
        .onChange(of: selectedRouteID) { _, newRouteID in
            selectedStationID = nil
            stationsForRoute = []
            guard let routeID = newRouteID else { return }
            Task { await loadStations(for: routeID) }
        }
    }

    private func loadStations(for routeID: String) async {
        isLoadingStations = true
        defer { isLoadingStations = false }
        do {
            stationsForRoute = try await MetraAPIService.shared.fetchStopsForRoute(routeID: routeID)
        } catch {
            stationsForRoute = []
        }
    }
}
