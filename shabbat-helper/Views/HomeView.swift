import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var isShowingCitySearch = false
    @State private var hasLoaded = false

    var body: some View {
        NavigationStack {
            ZStack {
                WeatherBackground()
                    .ignoresSafeArea()

                List {
                    currentLocationSection
                    favoritesSection
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable {
                    await viewModel.refresh()
                }
            }
            .foregroundStyle(.white)
//            .navigationTitle("Shabbat Times")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !viewModel.favorites.isEmpty {
                        EditButton()
                            .foregroundStyle(.white)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingCitySearch = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .foregroundStyle(.white)
                    .accessibilityLabel("Add City")
                }
            }
            .navigationDestination(for: SavedLocation.self) { location in
                ShabbatTimesDetailView(location: location)
            }
        }
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            await viewModel.load()
        }
        .sheet(isPresented: $isShowingCitySearch) {
            CitySearchView { location in
                Task {
                    await viewModel.addFavorite(location)
                }
            }
        }
    }

    @ViewBuilder
    private var currentLocationSection: some View {
        Section {
            if let row = viewModel.currentLocationRow {
                NavigationLink(value: row.location) {
                    FavoriteCityCard(row: row, isCurrentLocation: true)
                }
                .buttonStyle(.plain)
                .listCardRow()
            } else if viewModel.isRequestingCurrentLocation {
                FavoriteCityCard(
                    title: "Current Location",
                    detail: "Finding your location",
                    status: .loading,
                    isCurrentLocation: true
                )
                .listCardRow()
            } else if let currentLocationError = viewModel.currentLocationError {
                CurrentLocationUnavailableCard(message: currentLocationError) {
                    Task { await viewModel.refresh() }
                }
                .listCardRow()
            }
        }
    }

    @ViewBuilder
    private var favoritesSection: some View {
        Section {
            if viewModel.favoriteRows.isEmpty {
                EmptyFavoritesCard {
                    isShowingCitySearch = true
                }
                .listCardRow()
            } else {
                ForEach(viewModel.favoriteRows) { row in
                    NavigationLink(value: row.location) {
                        FavoriteCityCard(row: row, isCurrentLocation: false)
                    }
                    .buttonStyle(.plain)
                    .listCardRow()
                }
                .onDelete(perform: viewModel.deleteFavorites)
                .onMove(perform: viewModel.moveFavorites)
            }
        }
    }
}

private struct ShabbatTimesDetailView: View {
    @StateObject private var viewModel: ShabbatTimesViewModel
    @State private var hasLoaded = false

    init(location: SavedLocation) {
        _viewModel = StateObject(wrappedValue: ShabbatTimesViewModel(initialLocation: location))
    }

    var body: some View {
        ZStack {
            WeatherBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .foregroundStyle(.white)
        .navigationTitle(detailTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            await viewModel.load()
        }
    }

    private var detailTitle: String {
        switch viewModel.state {
        case .fetchingTimes(let location), .empty(let location):
            location.name
        case .loaded(_, let location):
            location.name
        case .error(_, let location):
            location?.name ?? "Shabbat Times"
        default:
            "Shabbat Times"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .initialLoading:
            LoadingStateView(title: "Loading Shabbat Times", systemImage: "sun.horizon.fill")
        case .requestingLocation:
            LoadingStateView(title: "Finding Your Location", systemImage: "location.fill")
        case .fetchingTimes(let location):
            HeaderView(locationName: location.name, detail: location.detail)
            LoadingStateView(title: "Fetching Candle Lighting", systemImage: "flame.fill")
        case .loaded(let times, let savedLocation):
            HeaderView(locationName: times.locationName, detail: times.locationDetail)
            CandleLightingCard(times: times)
            ShabbatDetailsCard(times: times, location: savedLocation)
        case .locationDenied:
            MessageCard(
                systemImage: "location.slash.fill",
                title: "Location Access Is Off",
                message: "Search for a city from the main list, or enable location access and try current location again.",
                primaryTitle: "Try Again",
                primarySystemImage: "location.fill",
                primaryAction: { Task { await viewModel.useCurrentLocation() } },
                secondaryTitle: "Refresh",
                secondarySystemImage: "arrow.clockwise",
                secondaryAction: { Task { await viewModel.refresh() } }
            )
        case .empty(let location):
            HeaderView(locationName: location.name, detail: location.detail)
            MessageCard(
                systemImage: "calendar.badge.exclamationmark",
                title: "No Candle Lighting Found",
                message: "We couldn’t find candle-lighting time for this location. Try another city or refresh in a moment.",
                primaryTitle: "Refresh",
                primarySystemImage: "arrow.clockwise",
                primaryAction: { Task { await viewModel.refresh() } },
                secondaryTitle: "Try Current",
                secondarySystemImage: "location.fill",
                secondaryAction: { Task { await viewModel.useCurrentLocation() } }
            )
        case .error(let message, let location):
            if let location {
                HeaderView(locationName: location.name, detail: location.detail)
            }
            MessageCard(
                systemImage: "wifi.exclamationmark",
                title: "Couldn’t Update Times",
                message: message,
                primaryTitle: "Try Again",
                primarySystemImage: "arrow.clockwise",
                primaryAction: { Task { await viewModel.refresh() } },
                secondaryTitle: "Current",
                secondarySystemImage: "location.fill",
                secondaryAction: { Task { await viewModel.useCurrentLocation() } }
            )
        }
    }
}

private struct FavoriteCityCard: View {
    @Environment(\.editMode) private var editMode
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let detail: String
    let status: HomeViewModel.RowStatus
    let isCurrentLocation: Bool

    private var isEditing: Bool {
        editMode?.wrappedValue.isEditing == true
    }

    private var titleLineLimit: Int {
        isEditing || dynamicTypeSize.isAccessibilitySize ? 2 : 1
    }

    init(row: HomeViewModel.LocationRow, isCurrentLocation: Bool) {
        self.title = isCurrentLocation ? "Current Location" : row.location.name
        self.detail = isCurrentLocation ? row.location.nameAndDetail : row.location.detail
        self.status = row.status
        self.isCurrentLocation = isCurrentLocation
    }

    init(title: String, detail: String, status: HomeViewModel.RowStatus, isCurrentLocation: Bool) {
        self.title = title
        self.detail = detail
        self.status = status
        self.isCurrentLocation = isCurrentLocation
    }

    var body: some View {
        HStack(alignment: .center, spacing: isEditing ? 10 : 14) {
            Image(systemName: isCurrentLocation ? "location.fill" : "building.2.fill")
                .font(.title3.weight(.semibold))
                .frame(width: isEditing ? 28 : 32, height: 32)
                .foregroundStyle(.white.opacity(0.86))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(titleLineLimit)
                    .minimumScaleFactor(isEditing ? 0.74 : 0.82)
                    .layoutPriority(3)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(isEditing ? 1 : 2)
                    .minimumScaleFactor(0.82)
                    .layoutPriority(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(2)

            if !isEditing {
                Spacer(minLength: 10)

                statusView
                    .frame(minWidth: 92, alignment: .trailing)
                    .layoutPriority(0)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .trailing)))
            }
        }
        .padding(.horizontal, isEditing ? 16 : 18)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 14, x: 0, y: 10)
        .animation(.snappy(duration: 0.24), value: isEditing)
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .loading:
            VStack(alignment: .trailing, spacing: 8) {
                ProgressView()
                    .tint(.white)
                Text("Loading")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        case .loaded(let times):
            let candleDate = times.candleLighting.dateValue
            VStack(alignment: .trailing, spacing: 5) {
                Text(candleDate.map { DisplayFormatters.time($0, timeZone: times.timeZone) } ?? "--")
                    .font(.title2.weight(.regular))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(candleDate.map { DisplayFormatters.shortDay($0, timeZone: times.timeZone) } ?? "Date unavailable")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        case .empty:
            StatusBadge(title: "No time", systemImage: "calendar.badge.exclamationmark")
        case .error(let message):
            StatusBadge(title: message, systemImage: "wifi.exclamationmark")
        }
    }
}

private struct StatusBadge: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundStyle(.white.opacity(0.82))
    }
}

private struct CurrentLocationUnavailableCard: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "location.slash.fill")
                .font(.title3.weight(.semibold))
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 5) {
                Text("Current Location")
                    .font(.headline.weight(.semibold))
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer(minLength: 10)

            Button(action: retry) {
                Image(systemName: "arrow.clockwise")
                    .font(.headline.weight(.semibold))
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Retry Current Location")
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct EmptyFavoritesCard: View {
    let addCity: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "plus.magnifyingglass")
                .font(.system(size: 42, weight: .semibold))
            Text("Add a Favourite City")
                .font(.title3.weight(.semibold))
            Text("Saved cities stay below current location and can be reordered or removed from this list.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.74))
                .multilineTextAlignment(.center)
            PillButton(title: "Add City", systemImage: "plus", action: addCity)
                .frame(maxWidth: 180)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 230)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private extension View {
    func listCardRow() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 7, leading: 20, bottom: 7, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

private extension SavedLocation {
    var nameAndDetail: String {
        detail.isEmpty || detail == name ? name : "\(name), \(detail)"
    }
}

private struct WeatherBackground: View {
    var body: some View {
        Image("background")
            .resizable()
            .scaledToFill()
            .overlay {
                LinearGradient(
                    colors: [
                        .black.opacity(0.34),
                        .black.opacity(0.16),
                        .black.opacity(0.42)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
    }
}

private struct HeaderView: View {
    let locationName: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(locationName)
                .font(.largeTitle.weight(.semibold))
                .minimumScaleFactor(0.72)
                .lineLimit(2)
            Text(detail)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CandleLightingCard: View {
    let times: ShabbatTimes

    var body: some View {
        let candleDate = times.candleLighting.dateValue

        VStack(alignment: .leading, spacing: 16) {
            Label("Candle Lighting", systemImage: "flame.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))

            Text(candleDate.map { DisplayFormatters.time($0, timeZone: times.timeZone) } ?? "Time unavailable")
                .font(.system(size: 68, weight: .thin, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .contentTransition(.numericText())

            VStack(alignment: .leading, spacing: 6) {
                Text(candleDate.map { DisplayFormatters.day($0, timeZone: times.timeZone) } ?? "Date unavailable")
                    .font(.title3.weight(.semibold))
                Text(times.timeZone.identifier.replacingOccurrences(of: "_", with: " "))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 22, x: 0, y: 16)
    }
}

private struct ShabbatDetailsCard: View {
    let times: ShabbatTimes
    let location: SavedLocation

    var body: some View {
        VStack(spacing: 0) {
            DetailRow(
                icon: "book.closed.fill",
                title: "Parsha",
                value: times.parsha?.title.replacingOccurrences(of: "Parashat ", with: "") ?? times.candleLighting.memo ?? "Not available"
            )

            Divider().overlay(.white.opacity(0.18))

            DetailRow(
                icon: "sparkles",
                title: "Havdalah",
                value: times.havdalah?.dateValue.map { DisplayFormatters.time($0, timeZone: times.timeZone) } ?? "Not available"
            )

            Divider().overlay(.white.opacity(0.18))

            DetailRow(
                icon: "calendar",
                title: "Hebrew Date",
                value: times.hebrewDate ?? "Not available"
            )

            Divider().overlay(.white.opacity(0.18))

            DetailRow(
                icon: "location.north.line.fill",
                title: "Coordinates",
                value: DisplayFormatters.shortCoordinate(latitude: location.latitude, longitude: location.longitude)
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 10)
    }
}

private struct DetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.headline)
                .frame(width: 28)
                .foregroundStyle(.white.opacity(0.82))

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.74))

            Spacer(minLength: 10)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .frame(minHeight: 52)
    }
}

private struct PillButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 46)
                .padding(.horizontal, 6)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct LoadingStateView: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: 48, weight: .semibold))
                .symbolEffect(.pulse)
            ProgressView()
                .tint(.white)
            Text(title)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct MessageCard: View {
    let systemImage: String
    let title: String
    let message: String
    let primaryTitle: String
    let primarySystemImage: String
    let primaryAction: () -> Void
    let secondaryTitle: String
    let secondarySystemImage: String
    let secondaryAction: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: 50, weight: .semibold))
            Text(title)
                .font(.title2.weight(.bold))
            Text(message)
                .font(.body)
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                PillButton(title: primaryTitle, systemImage: primarySystemImage, action: primaryAction)
                PillButton(title: secondaryTitle, systemImage: secondarySystemImage, action: secondaryAction)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 340)
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

#Preview {
    HomeView()
}
