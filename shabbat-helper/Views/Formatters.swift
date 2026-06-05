import Foundation

enum DisplayFormatters {
    static func time(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
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
