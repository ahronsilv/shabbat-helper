import Foundation

protocol LocationStoring {
    func loadLocation() -> SavedLocation?
    func saveLocation(_ location: SavedLocation)
    func clearLocation()
    func loadFavoriteLocations() -> [SavedLocation]
    func saveFavoriteLocations(_ locations: [SavedLocation])
}

final class LocationStore: LocationStoring {
    private let defaults: UserDefaults
    private let selectedLocationKey = "selectedLocation"
    private let favoritesKey = "favoriteLocations"
    private let didMigrateFavoritesKey = "didMigrateFavoriteLocations"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadLocation() -> SavedLocation? {
        guard let data = defaults.data(forKey: selectedLocationKey) else { return nil }
        return try? JSONDecoder().decode(SavedLocation.self, from: data)
    }

    func saveLocation(_ location: SavedLocation) {
        guard let data = try? JSONEncoder().encode(location) else { return }
        defaults.set(data, forKey: selectedLocationKey)
    }

    func clearLocation() {
        defaults.removeObject(forKey: selectedLocationKey)
    }

    func loadFavoriteLocations() -> [SavedLocation] {
        migrateSelectedLocationIfNeeded()

        guard let data = defaults.data(forKey: favoritesKey),
              let locations = try? JSONDecoder().decode([SavedLocation].self, from: data) else {
            return []
        }

        return unique(locations)
    }

    func saveFavoriteLocations(_ locations: [SavedLocation]) {
        let favorites = unique(locations).map { location in
            SavedLocation(
                id: location.id,
                name: location.name,
                detail: location.detail,
                latitude: location.latitude,
                longitude: location.longitude,
                timeZoneIdentifier: location.timeZoneIdentifier,
                isCurrentLocation: false
            )
        }

        guard let data = try? JSONEncoder().encode(favorites) else { return }
        defaults.set(data, forKey: favoritesKey)
        defaults.set(true, forKey: didMigrateFavoritesKey)
    }

    private func migrateSelectedLocationIfNeeded() {
        guard !defaults.bool(forKey: didMigrateFavoritesKey) else { return }
        defaults.set(true, forKey: didMigrateFavoritesKey)

        guard let selectedLocation = loadLocation(), !selectedLocation.isCurrentLocation else { return }

        let favorite = SavedLocation(
            id: selectedLocation.id,
            name: selectedLocation.name,
            detail: selectedLocation.detail,
            latitude: selectedLocation.latitude,
            longitude: selectedLocation.longitude,
            timeZoneIdentifier: selectedLocation.timeZoneIdentifier,
            isCurrentLocation: false
        )

        guard let data = try? JSONEncoder().encode([favorite]) else { return }
        defaults.set(data, forKey: favoritesKey)
    }

    private func unique(_ locations: [SavedLocation]) -> [SavedLocation] {
        var favorites: [SavedLocation] = []

        for location in locations {
            guard !favorites.contains(where: { $0.matchesPlace(location) }) else { continue }
            favorites.append(location)
        }

        return favorites
    }
}
