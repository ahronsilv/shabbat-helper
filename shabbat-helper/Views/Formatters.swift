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
        uses24HourTime ? "Use AM/PM Time" : "Use 24-Hour Time"
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
        formatter.dateStyle = .none
        formatter.dateFormat = uses24HourTime ? "HH:mm" : "h:mm a"
        return formatter.string(from: date)
    }

    static func day(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }

    static func shortDay(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    static func shortCoordinate(latitude: Double, longitude: Double) -> String {
        let latitudeText = abs(latitude).formatted(.number.precision(.fractionLength(2)))
        let longitudeText = abs(longitude).formatted(.number.precision(.fractionLength(2)))
        return "\(latitudeText)° \(latitude >= 0 ? "N" : "S"), \(longitudeText)° \(longitude >= 0 ? "E" : "W")"
    }
}
