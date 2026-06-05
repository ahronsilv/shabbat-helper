import SwiftUI

struct CitySearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CitySearchViewModel()

    let onSelect: (SavedLocation) -> Void

    var body: some View {
        NavigationStack {
            List {
                switch viewModel.state {
                case .idle:
                    SearchHintRow(
                        systemImage: "magnifyingglass",
                        title: "Search for a City",
                        message: "Enter a city name, then select a result to load candle-lighting times."
                    )
                    .listRowBackground(Color.clear)
                case .loading:
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Searching cities…")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 16)
                case .results:
                    ForEach(viewModel.results) { location in
                        Button {
                            onSelect(location)
                            dismiss()
                        } label: {
                            CityResultRow(location: location)
                        }
                        .buttonStyle(.plain)
                    }
                case .noResults:
                    SearchHintRow(
                        systemImage: "mappin.slash",
                        title: "No Results",
                        message: "Try a nearby city, add a country, or check the spelling."
                    )
                    .listRowBackground(Color.clear)
                case .error(let message):
                    SearchHintRow(
                        systemImage: "exclamationmark.triangle",
                        title: "Search Failed",
                        message: message
                    )
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Change City")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "City or address")
            .onChange(of: viewModel.query) { _, _ in
                viewModel.scheduleSearch()
            }
            .onSubmit(of: .search) {
                viewModel.submitSearch()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct CityResultRow: View {
    let location: SavedLocation

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(location.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }
}

private struct SearchHintRow: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding(.vertical, 24)
    }
}

#Preview {
    CitySearchView { _ in }
}
