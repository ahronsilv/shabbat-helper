import SwiftUI

struct CitySearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CitySearchViewModel()
    @State private var path: [SavedLocation] = []
    @FocusState private var isSearchFocused: Bool

    let savedLocations: [SavedLocation]
    let focusesSearchOnAppear: Bool
    let onAdd: (SavedLocation) async -> Bool

    var body: some View {
        NavigationStack(path: $path) {
            List {
                addressSuggestionsSection

                switch viewModel.state {
                case .idle:
                    SearchHintRow(
                        systemImage: "magnifyingglass",
                        title: String(localized: "search_for_city_title"),
                        message: String(localized: "search_hint_message")
                    )
                    .listRowBackground(Color.clear)
                case .loading:
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("searching_cities")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 16)
                case .results:
                    ForEach(viewModel.results) { location in
                        Button {
                            path.append(location)
                        } label: {
                            CityResultRow(location: location, isAlreadySaved: isAlreadySaved(location))
                        }
                        .buttonStyle(.plain)
                    }
                case .noResults:
                    SearchHintRow(
                        systemImage: "mappin.slash",
                        title: String(localized: "no_results"),
                        message: String(localized: "no_results_message")
                    )
                    .listRowBackground(Color.clear)
                case .error(let message):
                    SearchHintRow(
                        systemImage: "exclamationmark.triangle",
                        title: String(localized: "search_failed"),
                        message: message
                    )
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("add_city")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "city_or_address")
            .searchFocused($isSearchFocused)
            .onChange(of: viewModel.query) { _, _ in
                viewModel.scheduleSearch()
            }
            .onSubmit(of: .search) {
                viewModel.submitSearch()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        dismiss()
                    }
                }
            }
            .navigationDestination(for: SavedLocation.self) { location in
                CityPreviewView(
                    location: location,
                    isAlreadySaved: isAlreadySaved(location),
                    onAdd: onAdd,
                    onClose: { popPreview() },
                    onDone: { dismiss() }
                )
            }
            .task {
                viewModel.loadAddressSuggestionsIfNeeded()
                guard focusesSearchOnAppear else { return }
                try? await Task.sleep(for: .milliseconds(250))
                isSearchFocused = true
            }
        }
    }

    @ViewBuilder
    private var addressSuggestionsSection: some View {
        if !viewModel.addressSuggestions.isEmpty {
            Section("suggestions") {
                ForEach(viewModel.addressSuggestions) { suggestion in
                    Button {
                        path.append(suggestion.location)
                    } label: {
                        AddressSuggestionRow(
                            suggestion: suggestion,
                            isAlreadySaved: isAlreadySaved(suggestion.location)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func isAlreadySaved(_ location: SavedLocation) -> Bool {
        savedLocations.contains { $0.matchesPlace(location) }
    }

    private func popPreview() {
        guard !path.isEmpty else {
            dismiss()
            return
        }

        path.removeLast()
    }
}

private struct CityResultRow: View {
    let location: SavedLocation
    let isAlreadySaved: Bool

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

            if isAlreadySaved {
                Label("already_added", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .labelStyle(.iconOnly)
                    .accessibilityLabel("already_added")
            } else {
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct AddressSuggestionRow: View {
    let suggestion: CitySearchViewModel.AddressSuggestion
    let isAlreadySaved: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: suggestion.label == String(localized: "home_suggestion_label") ? "house.fill" : "briefcase.fill")
                .font(.title3.weight(.semibold))
                .frame(width: 28)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(suggestion.location.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            if isAlreadySaved {
                Label("already_added", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .labelStyle(.iconOnly)
                    .accessibilityLabel("already_added")
            } else {
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct CityPreviewView: View {
    private enum AddState {
        case idle
        case adding
        case alreadyAdded
    }

    @AppStorage(TimeFormatPreference.uses24HourTimeKey) private var uses24HourTime = TimeFormatPreference.defaultUses24HourTime
    @StateObject private var viewModel: ShabbatTimesViewModel
    @State private var hasLoaded = false
    @State private var addState: AddState = .idle

    let location: SavedLocation
    let isAlreadySaved: Bool
    let onAdd: (SavedLocation) async -> Bool
    let onClose: () -> Void
    let onDone: () -> Void

    private var isAdding: Bool {
        addState == .adding
    }

    private var cannotAdd: Bool {
        isAlreadySaved || addState == .alreadyAdded
    }

    init(
        location: SavedLocation,
        isAlreadySaved: Bool,
        onAdd: @escaping (SavedLocation) async -> Bool,
        onClose: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) {
        self.location = location
        self.isAlreadySaved = isAlreadySaved
        self.onAdd = onAdd
        self.onClose = onClose
        self.onDone = onDone
        _viewModel = StateObject(wrappedValue: ShabbatTimesViewModel(initialLocation: location))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PreviewHeader(location: location)

                previewContent

                if cannotAdd {
                    AlreadyAddedNotice()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(location.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                }
                .accessibilityLabel("close_city_preview")
            }

            ToolbarItem(placement: .confirmationAction) {
                if !cannotAdd {
                    Button {
                        Task {
                            await addCity()
                        }
                    } label: {
                        if isAdding {
                            ProgressView()
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                    }
                    .disabled(isAdding)
                    .accessibilityLabel("add_city")
                }
            }
        }
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            await viewModel.load()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch viewModel.state {
        case .initialLoading, .requestingLocation, .fetchingTimes:
            PreviewLoadingCard()
        case .loaded(let times, _):
            PreviewCandleCard(times: times, uses24HourTime: uses24HourTime)
            PreviewDetailsCard(times: times, location: location, uses24HourTime: uses24HourTime)
        case .locationDenied:
            PreviewMessageCard(
                systemImage: "location.slash",
                title: String(localized: "location_access_is_off"),
                message: String(localized: "preview_location_denied_message")
            )
        case .empty:
            PreviewMessageCard(
                systemImage: "calendar.badge.exclamationmark",
                title: String(localized: "no_candle_lighting_found"),
                message: String(localized: "preview_no_candle_lighting_message")
            )
        case .error(let message, _):
            PreviewMessageCard(
                systemImage: "wifi.exclamationmark",
                title: String(localized: "could_not_update_times"),
                message: message
            )
        }
    }

    private func addCity() async {
        guard !cannotAdd else { return }

        addState = .adding
        let didAdd = await onAdd(location)

        if didAdd {
            onDone()
        } else {
            addState = .alreadyAdded
        }
    }
}

private struct PreviewHeader: View {
    let location: SavedLocation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(location.name)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            Text(location.detail)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PreviewCandleCard: View {
    let times: ShabbatTimes
    let uses24HourTime: Bool

    var body: some View {
        let candleDate = times.candleLighting.dateValue

        VStack(alignment: .leading, spacing: 14) {
            Label("candle_lighting", systemImage: "flame.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(candleDate.map { DisplayFormatters.time($0, timeZone: times.timeZone, uses24HourTime: uses24HourTime) } ?? String(localized: "time_unavailable"))
                .font(.system(size: 58, weight: .thin, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .monospacedDigit()

            Text(candleDate.map { DisplayFormatters.day($0, timeZone: times.timeZone) } ?? String(localized: "date_unavailable"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct PreviewDetailsCard: View {
    let times: ShabbatTimes
    let location: SavedLocation
    let uses24HourTime: Bool

    var body: some View {
        VStack(spacing: 0) {
            PreviewDetailRow(
                icon: "mappin.and.ellipse",
                title: String(localized: "region"),
                value: times.locationDetail
            )

            Divider()

            PreviewDetailRow(
                icon: "sparkles",
                title: String(localized: "havdalah"),
                value: times.havdalah?.dateValue.map { DisplayFormatters.time($0, timeZone: times.timeZone, uses24HourTime: uses24HourTime) } ?? String(localized: "not_available")
            )

            Divider()

            PreviewDetailRow(
                icon: "book.closed.fill",
                title: String(localized: "parsha"),
                value: times.parsha?.displayTitle ?? times.candleLighting.memo ?? String(localized: "not_available")
            )

            Divider()

            PreviewDetailRow(
                icon: "location.north.line.fill",
                title: String(localized: "coordinates"),
                value: DisplayFormatters.shortCoordinate(latitude: location.latitude, longitude: location.longitude)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct PreviewDetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .frame(width: 26)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 10)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .frame(minHeight: 50)
    }
}

private struct PreviewLoadingCard: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("fetching_candle_lighting")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct PreviewMessageCard: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
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
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct AlreadyAddedNotice: View {
    var body: some View {
        Label("already_added", systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityLabel("already_added")
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
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
    }
}

#Preview {
    CitySearchView(savedLocations: [], focusesSearchOnAppear: false) { _ in true }
}
