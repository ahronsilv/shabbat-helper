import Foundation
import CoreLocation

@MainActor
protocol LocationServicing {
    func requestCurrentLocation() async throws -> SavedLocation
}

enum LocationServiceError: LocalizedError {
    case unavailable
    case denied
    case unableToFindLocation

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Location services are unavailable on this device."
        case .denied:
            "Location access is off."
        case .unableToFindLocation:
            "The current location could not be determined."
        }
    }
}

@MainActor
final class LocationService: NSObject, LocationServicing, CLLocationManagerDelegate {
    private let manager: CLLocationManager
    private let geocoder: CLGeocoder
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var locationTimeoutTask: Task<Void, Never>?

    init(manager: CLLocationManager = CLLocationManager(), geocoder: CLGeocoder = CLGeocoder()) {
        self.manager = manager
        self.geocoder = geocoder
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func requestCurrentLocation() async throws -> SavedLocation {
        guard CLLocationManager.locationServicesEnabled() else {
            throw LocationServiceError.unavailable
        }

        let status = await authorizedStatus()
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            throw LocationServiceError.denied
        }

        let location = try await requestOneShotLocation()
        return await makeSavedLocation(from: location)
    }

    private func authorizedStatus() async -> CLAuthorizationStatus {
        switch manager.authorizationStatus {
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                authorizationContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        default:
            return manager.authorizationStatus
        }
    }

    private func requestOneShotLocation() async throws -> CLLocation {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                locationContinuation?.resume(throwing: LocationServiceError.unableToFindLocation)
                locationTimeoutTask?.cancel()

                locationContinuation = continuation
                manager.startUpdatingLocation()

                locationTimeoutTask = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 15_000_000_000)
                    guard !Task.isCancelled else { return }

                    await MainActor.run {
                        self?.finishLocationRequest(with: .failure(LocationServiceError.unableToFindLocation))
                    }
                }
            }
        } onCancel: {
            Task { @MainActor in
                finishLocationRequest(with: .failure(CancellationError()))
            }
        }
    }

    private func makeSavedLocation(from location: CLLocation) async -> SavedLocation {
        let placemark = try? await geocoder.reverseGeocodeLocation(location).first
        let name = placemark?.locality ?? placemark?.name ?? "Current Location"
        let detailParts = [placemark?.administrativeArea, placemark?.country].compactMap { $0 }
        let detail = detailParts.isEmpty ? "Current Location" : detailParts.joined(separator: ", ")
        let timeZoneIdentifier = placemark?.timeZone?.identifier ?? TimeZone.current.identifier

        return SavedLocation(
            name: name,
            detail: detail,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timeZoneIdentifier: timeZoneIdentifier,
            isCurrentLocation: true
        )
    }

    private func finishLocationRequest(with result: Result<CLLocation, Error>) {
        guard let continuation = locationContinuation else { return }

        locationContinuation = nil
        locationTimeoutTask?.cancel()
        locationTimeoutTask = nil
        manager.stopUpdatingLocation()

        switch result {
        case .success(let location):
            continuation.resume(returning: location)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationContinuation?.resume(returning: status)
            authorizationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else {
                finishLocationRequest(with: .failure(LocationServiceError.unableToFindLocation))
                return
            }

            finishLocationRequest(with: .success(location))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if let error = error as? CLError, error.code == .locationUnknown {
                return
            }

            finishLocationRequest(with: .failure(error))
        }
    }
}
