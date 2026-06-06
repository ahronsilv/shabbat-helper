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

    func testLocaleTimeFormatPreferenceDetectsHourCycle() {
        XCTAssertFalse(TimeFormatPreference.localePrefers24HourTime(Locale(identifier: "en_US")))
        XCTAssertTrue(TimeFormatPreference.localePrefers24HourTime(Locale(identifier: "en_GB")))
    }

    func testStoredTimeFormatPreferenceUsesLocaleDefaultWhenUnset() {
        XCTAssertEqual(
            TimeFormatPreference.storedUses24HourTime(defaults: defaults),
            TimeFormatPreference.defaultUses24HourTime
        )
    }

    func testStoredTimeFormatPreferencePreservesSavedChoice() {
        defaults.set(false, forKey: TimeFormatPreference.uses24HourTimeKey)

        XCTAssertFalse(TimeFormatPreference.storedUses24HourTime(defaults: defaults))
    }

    func testTimeFormatterForcesTwelveHourTimeInTwentyFourHourLocale() throws {
        let date = Date(timeIntervalSince1970: 1_715_366_400)
        let timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let text = DisplayFormatters.time(
            date,
            timeZone: timeZone,
            locale: Locale(identifier: "en_GB"),
            uses24HourTime: false
        )

        XCTAssertTrue(text.localizedCaseInsensitiveContains("PM"))
        XCTAssertFalse(text.contains("18:"))
    }

    func testTimeFormatterForcesTwentyFourHourTimeInTwelveHourLocale() throws {
        let date = Date(timeIntervalSince1970: 1_715_366_400)
        let timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let text = DisplayFormatters.time(
            date,
            timeZone: timeZone,
            locale: Locale(identifier: "en_US"),
            uses24HourTime: true
        )

        XCTAssertTrue(text.contains("18:"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("PM"))
    }

    func testHebcalLanguageMapperUsesSupportedApiLanguages() {
        XCTAssertEqual(HebcalLanguageMapper.hebcalLanguageCode(for: Locale(identifier: "fr")), "fr")
        XCTAssertEqual(HebcalLanguageMapper.hebcalLanguageCode(for: Locale(identifier: "ru")), "ru")
        XCTAssertEqual(HebcalLanguageMapper.hebcalLanguageCode(for: Locale(identifier: "he")), "he-x-NoNikud")
    }

    func testHebcalLanguageMapperFallsBackForEnglishAndAmharic() {
        XCTAssertNil(HebcalLanguageMapper.hebcalLanguageCode(for: Locale(identifier: "en")))
        XCTAssertNil(HebcalLanguageMapper.hebcalLanguageCode(for: Locale(identifier: "am")))
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

    @MainActor
    func testAddFavoriteRefusesDuplicateCities() async {
        let viewModel = HomeViewModel(
            hebcalService: MissingTimesHebcalService(),
            locationService: DeniedLocationService(),
            locationStore: store
        )
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

        let firstAdd = await viewModel.addFavorite(jerusalem)
        let secondAdd = await viewModel.addFavorite(duplicateJerusalem)

        XCTAssertTrue(firstAdd)
        XCTAssertFalse(secondAdd)
        XCTAssertEqual(viewModel.favorites.map(\.name), ["Jerusalem"])
    }
}

private struct MissingTimesHebcalService: HebcalServicing {
    func fetchUpcomingShabbatTimes(for location: SavedLocation) async throws -> ShabbatTimes {
        throw HebcalServiceError.missingCandleLighting
    }
}

@MainActor
private struct DeniedLocationService: LocationServicing {
    func requestCurrentLocation() async throws -> SavedLocation {
        throw LocationServiceError.denied
    }
}
