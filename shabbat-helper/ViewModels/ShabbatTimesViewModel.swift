import Foundation
import Combine

@MainActor
final class ShabbatTimesViewModel: ObservableObject {
    enum ViewState: Equatable {
        case initialLoading
        case requestingLocation
        case fetchingTimes(SavedLocation)
        case loaded(ShabbatTimes, SavedLocation)
        case locationDenied
        case empty(SavedLocation)
        case error(String, SavedLocation?)
    }

    @Published private(set) var state: ViewState = .initialLoading

    private let hebcalService: HebcalServicing
    private let locationService: LocationServicing
    private let locationStore: LocationStoring
    private var activeLocation: SavedLocation?

    init(initialLocation: SavedLocation? = nil) {
        self.hebcalService = HebcalService()
        self.locationService = LocationService()
        self.locationStore = LocationStore()
        self.activeLocation = initialLocation
    }

    init(
        hebcalService: HebcalServicing,
        locationService: LocationServicing,
        locationStore: LocationStoring,
        initialLocation: SavedLocation? = nil
    ) {
        self.hebcalService = hebcalService
        self.locationService = locationService
        self.locationStore = locationStore
        self.activeLocation = initialLocation
    }

    func load() async {
        if let activeLocation {
            await fetchTimes(for: activeLocation)
            return
        }

        if let savedLocation = locationStore.loadLocation() {
            activeLocation = savedLocation
            await fetchTimes(for: savedLocation)
            return
        }

        await useCurrentLocation()
    }

    func useCurrentLocation() async {
        state = .requestingLocation

        do {
            let location = try await locationService.requestCurrentLocation()
            activeLocation = location
            await fetchTimes(for: location)
        } catch {
            state = .locationDenied
        }
    }

    func selectLocation(_ location: SavedLocation) async {
        activeLocation = location
        await fetchTimes(for: location)
    }

    func refresh() async {
        guard let activeLocation else {
            await load()
            return
        }

        await fetchTimes(for: activeLocation)
    }

    private func fetchTimes(for location: SavedLocation) async {
        state = .fetchingTimes(location)

        do {
            let times = try await hebcalService.fetchUpcomingShabbatTimes(for: location)
            state = .loaded(times, location)
        } catch HebcalServiceError.missingCandleLighting {
            state = .empty(location)
        } catch {
            #if DEBUG
            print("Hebcal fetch failed:", error)
            #endif
            state = .error("Please check your internet connection and try again.", location)
        }
    }
}
