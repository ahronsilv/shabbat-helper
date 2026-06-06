import Foundation

enum TimeFormatPreference {
    static let uses24HourTimeKey = "uses24HourTime"

    static var defaultUses24HourTime: Bool {
        localePrefers24HourTime(.autoupdatingCurrent)
    }

    static func registerDefaults(_ defaults: UserDefaults = .standard) {
        defaults.register(defaults: [uses24HourTimeKey: defaultUses24HourTime])
    }

    static func storedUses24HourTime(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: uses24HourTimeKey) as? Bool ?? defaultUses24HourTime
    }

    static func localePrefers24HourTime(_ locale: Locale) -> Bool {
        guard let hourFormat = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale) else {
            return false
        }

        return !hourFormat.contains("a")
    }

    static func toggleTitle(uses24HourTime: Bool) -> String {
        uses24HourTime
            ? String(localized: "time_format_use_ampm")
            : String(localized: "time_format_use_24_hour")
    }
}

enum DisplayFormatters {
    static func time(
        _ date: Date,
        timeZone: TimeZone,
        uses24HourTime: Bool = TimeFormatPreference.storedUses24HourTime()
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(uses24HourTime ? "HHmm" : "jmm")
        return formatter.string(from: date)
    }

    static func day(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEEMMMMd")
        return formatter.string(from: date)
    }

    static func shortDay(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEMMMd")
        return formatter.string(from: date)
    }

    static func shortCoordinate(latitude: Double, longitude: Double) -> String {
        let latitudeText = abs(latitude).formatted(.number.precision(.fractionLength(2)))
        let longitudeText = abs(longitude).formatted(.number.precision(.fractionLength(2)))
        let latitudeDirection = String(localized: latitude >= 0 ? "coordinate_north_abbreviation" : "coordinate_south_abbreviation")
        let longitudeDirection = String(localized: longitude >= 0 ? "coordinate_east_abbreviation" : "coordinate_west_abbreviation")

        return String(
            format: String(localized: "coordinates_format"),
            latitudeText,
            latitudeDirection,
            longitudeText,
            longitudeDirection
        )
    }
}
