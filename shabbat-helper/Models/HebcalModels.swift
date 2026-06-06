import Foundation

struct HebcalResponse: Decodable {
    let title: String
    let location: HebcalLocation?
    let items: [HebcalItem]
}

struct HebcalLocation: Decodable {
    let title: String?
    let city: String?
    let tzid: String?
    let country: String?
    let admin1: String?
}

struct HebcalItem: Decodable, Equatable, Identifiable {
    var id: String { "\(category)-\(date)-\(title)" }

    let title: String
    let date: String
    let category: String
    let titleOriginal: String?
    let hebrew: String?
    let hdate: String?
    let memo: String?

    enum CodingKeys: String, CodingKey {
        case title
        case date
        case category
        case titleOriginal = "title_orig"
        case hebrew
        case hdate
        case memo
    }

    var dateValue: Date? {
        Self.dateTimeFormatter.date(from: date) ?? Self.dateOnlyFormatter.date(from: date)
    }

    var displayTitle: String {
        if Locale.autoupdatingCurrent.language.languageCode?.identifier == "he", let hebrew, !hebrew.isEmpty {
            return hebrew
        }

        return title
    }

    private static let dateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct ShabbatTimes: Equatable {
    let locationName: String
    let locationDetail: String
    let timeZone: TimeZone
    let candleLighting: HebcalItem
    let havdalah: HebcalItem?
    let parsha: HebcalItem?
    let hebrewDate: String?
    let generatedAt: Date
}
