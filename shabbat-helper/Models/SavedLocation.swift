import Foundation
import CoreLocation

struct SavedLocation: Codable, Equatable, Hashable, Identifiable {
    let id: UUID
    let name: String
    let detail: String
    let latitude: Double
    let longitude: Double
    let timeZoneIdentifier: String
    let isCurrentLocation: Bool

    init(
        id: UUID = UUID(),
        name: String,
        detail: String,
        latitude: Double,
        longitude: Double,
        timeZoneIdentifier: String,
        isCurrentLocation: Bool = false
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
        self.isCurrentLocation = isCurrentLocation
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    func matchesPlace(_ other: SavedLocation) -> Bool {
        normalizedName == other.normalizedName
            && abs(latitude - other.latitude) < 0.01
            && abs(longitude - other.longitude) < 0.01
    }

    private var normalizedName: String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
