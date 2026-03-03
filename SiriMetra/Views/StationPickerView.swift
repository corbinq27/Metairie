import SwiftUI

/// A searchable station picker for selecting a Metra station.
struct StationPickerView: View {
    let stations: [Station]
    @Binding var selectedStationID: String?
    @State private var searchText = ""

    private var filteredStations: [Station] {
        if searchText.isEmpty {
            return stations
        }
        return stations.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search stations...", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)

            // Station list
            List(filteredStations) { station in
                Button {
                    selectedStationID = station.id
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(station.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            if let zone = station.zone {
                                Text("Zone \(zone)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if selectedStationID == station.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .listRowBackground(
                    selectedStationID == station.id
                    ? Color.blue.opacity(0.1)
                    : Color.clear
                )
            }
            .listStyle(.plain)
        }
    }
}
