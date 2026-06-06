import Foundation
import Combine
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    enum RowStatus: Equatable {
        case loading
        case loaded(ShabbatTimes)
        case empty
        case error(String)
    }

    struct LocationRow: Identifiable, Equatable {
        let location: SavedLocation
        var status: RowStatus

        var id: UUID { location.id }
    }

    @Published private(set) var currentLocationRow: LocationRow?
    @Published private(set) var favorites: [SavedLocation] = []
    @Published private(set) var favoriteRows: [LocationRow] = []
    @Published private(set) var isRequestingCurrentLocation = false
    @Published private(set) var currentLocationError: String?

    private let hebcalService: HebcalServicing
    private let locationService: LocationServicing
    private let locationStore: LocationStoring

    init() {
        self.hebcalService = HebcalService()
        self.locationService = LocationService()
        self.locationStore = LocationStore()
    }

    init(
        hebcalService: HebcalServicing,
        locationService: LocationServicing,
        locationStore: LocationStoring
    ) {
        self.hebcalService = hebcalService
        self.locationService = locationService
        self.locationStore = locationStore
    }

    func load() async {
        favorites = locationStore.loadFavoriteLocations()
        favoriteRows = favorites.map { LocationRow(location: $0, status: .loading) }

        async let currentLocation: Void = loadCurrentLocation()
        async let favoriteTimes: Void = refreshFavoriteRows()
        _ = await (currentLocation, favoriteTimes)
    }

    func refresh() async {
        async let currentLocation: Void = refreshCurrentLocation()
        async let favoriteTimes: Void = refreshFavoriteRows()
        _ = await (currentLocation, favoriteTimes)
    }

    func isFavorite(_ location: SavedLocation) -> Bool {
        favorites.contains { $0.matchesPlace(location) }
    }

    @discardableResult
    func addFavorite(_ location: SavedLocation) async -> Bool {
        let favorite = SavedLocation(
            name: location.name,
            detail: location.detail,
            latitude: location.latitude,
            longitude: location.longitude,
            timeZoneIdentifier: location.timeZoneIdentifier,
            isCurrentLocation: false
        )

        guard !isFavorite(favorite) else { return false }

        favorites.append(favorite)
        locationStore.saveFavoriteLocations(favorites)
        favoriteRows.append(LocationRow(location: favorite, status: .loading))
        await refreshFavorite(favorite)
        return true
    }

    func deleteFavorites(at offsets: IndexSet) {
        favorites.remove(atOffsets: offsets)
        favoriteRows.remove(atOffsets: offsets)
        locationStore.saveFavoriteLocations(favorites)
    }

    func moveFavorites(from source: IndexSet, to destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)
        favoriteRows.move(fromOffsets: source, toOffset: destination)
        locationStore.saveFavoriteLocations(favorites)
    }

    private func loadCurrentLocation() async {
        isRequestingCurrentLocation = true
        currentLocationError = nil

        do {
            let location = try await locationService.requestCurrentLocation()
            currentLocationRow = LocationRow(location: location, status: .loading)
            isRequestingCurrentLocation = false
            await refreshCurrentLocation()
        } catch {
            isRequestingCurrentLocation = false
            currentLocationRow = nil
            currentLocationError = error.localizedDescription
        }
    }

    private func refreshCurrentLocation() async {
        guard let location = currentLocationRow?.location else {
            await loadCurrentLocation()
            return
        }

        currentLocationRow = LocationRow(location: location, status: .loading)
        let status = await fetchStatus(for: location)
        currentLocationRow = LocationRow(location: location, status: status)
    }

    private func refreshFavoriteRows() async {
        for location in favorites {
            await refreshFavorite(location)
        }
    }

    private func refreshFavorite(_ location: SavedLocation) async {
        updateFavorite(location, status: .loading)
        let status = await fetchStatus(for: location)
        updateFavorite(location, status: status)
    }

    private func updateFavorite(_ location: SavedLocation, status: RowStatus) {
        guard let index = favoriteRows.firstIndex(where: { $0.location.id == location.id }) else { return }
        favoriteRows[index] = LocationRow(location: location, status: status)
    }

    private func fetchStatus(for location: SavedLocation) async -> RowStatus {
        do {
            let times = try await hebcalService.fetchUpcomingShabbatTimes(for: location)
            return .loaded(times)
        } catch HebcalServiceError.missingCandleLighting {
            return .empty
        } catch {
            #if DEBUG
            print("Hebcal fetch failed:", error)
            #endif
            return .error(String(localized: "error_could_not_update_short"))
        }
    }
}
