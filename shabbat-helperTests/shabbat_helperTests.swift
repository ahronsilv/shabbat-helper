import Foundation
import XCTest
@testable import shabbat_helper

final class shabbat_helperTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: LocationStore!

    override func setUpWithError() throws {
        suiteName = "LocationStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = LocationStore(defaults: defaults)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        suiteName = nil
        defaults = nil
        store = nil
    }

    func testLoadFavoriteLocationsMigratesLegacySelectedLocation() {
        let legacyLocation = SavedLocation(
            name: "Jerusalem",
            detail: "Israel",
            latitude: 31.778,
            longitude: 35.235,
            timeZoneIdentifier: "Asia/Jerusalem"
        )

        store.saveLocation(legacyLocation)

        let favorites = store.loadFavoriteLocations()

        XCTAssertEqual(favorites.count, 1)
        XCTAssertEqual(favorites.first?.name, "Jerusalem")
        XCTAssertEqual(favorites.first?.isCurrentLocation, false)
    }

    func testLoadFavoriteLocationsDoesNotMigrateCurrentLocation() {
        let currentLocation = SavedLocation(
            name: "Current Location",
            detail: "Israel",
            latitude: 31.778,
            longitude: 35.235,
            timeZoneIdentifier: "Asia/Jerusalem",
            isCurrentLocation: true
        )

        store.saveLocation(currentLocation)

        XCTAssertTrue(store.loadFavoriteLocations().isEmpty)
    }

    func testSaveFavoriteLocationsPreservesOrderAndKeepsCurrentLocationSeparate() {
        let telAviv = SavedLocation(
            name: "Tel Aviv",
            detail: "Israel",
            latitude: 32.085,
            longitude: 34.782,
            timeZoneIdentifier: "Asia/Jerusalem"
        )
        let currentLocation = SavedLocation(
            name: "Current Location",
            detail: "Israel",
            latitude: 31.778,
            longitude: 35.235,
            timeZoneIdentifier: "Asia/Jerusalem",
            isCurrentLocation: true
        )

        store.saveFavoriteLocations([telAviv, currentLocation])

        let favorites = store.loadFavoriteLocations()
        XCTAssertEqual(favorites.map(\.name), ["Tel Aviv", "Current Location"])
        XCTAssertEqual(favorites.map(\.isCurrentLocation), [false, false])
    }

    func testSaveFavoriteLocationsRemovesDuplicateCities() {
        let jerusalem = SavedLocation(
            name: "Jerusalem",
            detail: "Israel",
            latitude: 31.778,
            longitude: 35.235,
            timeZoneIdentifier: "Asia/Jerusalem"
        )
        let duplicateJerusalem = SavedLocation(
            name: "jerusalem",
            detail: "Jerusalem District, Israel",
            latitude: 31.779,
            longitude: 35.234,
            timeZoneIdentifier: "Asia/Jerusalem"
        )
        let telAviv = SavedLocation(
            name: "Tel Aviv",
            detail: "Israel",
            latitude: 32.085,
            longitude: 34.782,
            timeZoneIdentifier: "Asia/Jerusalem"
        )

        store.saveFavoriteLocations([jerusalem, duplicateJerusalem, telAviv])

        let favorites = store.loadFavoriteLocations()
        XCTAssertEqual(favorites.map(\.name), ["Jerusalem", "Tel Aviv"])
    }
}
