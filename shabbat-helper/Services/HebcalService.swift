import Foundation

protocol HebcalServicing {
    func fetchUpcomingShabbatTimes(for location: SavedLocation) async throws -> ShabbatTimes
}

protocol HTTPClient {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPClient {}

enum HebcalServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case requestFailed(Int)
    case missingCandleLighting

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            String(localized: "hebcal_error_invalid_url")
        case .invalidResponse:
            String(localized: "hebcal_error_invalid_response")
        case .requestFailed:
            String(localized: "hebcal_error_request_failed")
        case .missingCandleLighting:
            String(localized: "hebcal_error_missing_candle_lighting")
        }
    }
}

final class HebcalService: HebcalServicing {
    private let client: HTTPClient
    private let baseURL: URL
    private let calendar = Calendar(identifier: .gregorian)

    init(
        client: HTTPClient = URLSession.shared,
        baseURL: URL = URL(string: "https://www.hebcal.com/shabbat")!
    ) {
        self.client = client
        self.baseURL = baseURL
    }

    func fetchUpcomingShabbatTimes(for location: SavedLocation) async throws -> ShabbatTimes {
        let now = Date()
        let currentWindow = try await fetchShabbatTimes(for: location, date: now)

        if currentWindow.candleLighting.dateValue.map({ $0 >= now }) == true {
            return currentWindow
        }

        let nextWeek = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        return try await fetchShabbatTimes(for: location, date: nextWeek)
    }

    private func fetchShabbatTimes(for location: SavedLocation, date: Date) async throws -> ShabbatTimes {
        let url = try makeURL(for: location, date: date)
        let (data, response) = try await client.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HebcalServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw HebcalServiceError.requestFailed(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let hebcalResponse = try decoder.decode(HebcalResponse.self, from: data)
        return try makeSummary(from: hebcalResponse, fallbackLocation: location)
    }

    private func makeURL(for location: SavedLocation, date: Date) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw HebcalServiceError.invalidURL
        }

        let dateComponents = calendar.dateComponents(in: location.timeZone, from: date)
        var queryItems = [
            URLQueryItem(name: "cfg", value: "json"),
            URLQueryItem(name: "latitude", value: String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), location.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), location.longitude)),
            URLQueryItem(name: "tzid", value: location.timeZoneIdentifier),
            URLQueryItem(name: "M", value: "on"),
            URLQueryItem(name: "leyning", value: "off"),
            URLQueryItem(name: "gy", value: dateComponents.year.map(String.init)),
            URLQueryItem(name: "gm", value: dateComponents.month.map(String.init)),
            URLQueryItem(name: "gd", value: dateComponents.day.map(String.init))
        ]

        if let hebcalLanguageCode = HebcalLanguageMapper.hebcalLanguageCode() {
            queryItems.append(URLQueryItem(name: "lg", value: hebcalLanguageCode))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw HebcalServiceError.invalidURL
        }

        return url
    }

    private func makeSummary(from response: HebcalResponse, fallbackLocation: SavedLocation) throws -> ShabbatTimes {
        guard let candleLighting = response.items
            .filter({ $0.category == "candles" })
            .sorted(by: { ($0.dateValue ?? .distantFuture) < ($1.dateValue ?? .distantFuture) })
            .first else {
            throw HebcalServiceError.missingCandleLighting
        }

        let locationName = response.location?.city ?? fallbackLocation.name
        let locationDetail = response.location?.title ?? fallbackLocation.detail
        let timeZoneIdentifier = response.location?.tzid ?? fallbackLocation.timeZoneIdentifier
        let timeZone = TimeZone(identifier: timeZoneIdentifier) ?? fallbackLocation.timeZone
        let parsha = response.items.first { $0.category == "parashat" }
        let havdalah = response.items.first { $0.category == "havdalah" }
        let hebrewDate = parsha?.hdate ?? candleLighting.hdate

        return ShabbatTimes(
            locationName: locationName,
            locationDetail: locationDetail,
            timeZone: timeZone,
            candleLighting: candleLighting,
            havdalah: havdalah,
            parsha: parsha,
            hebrewDate: hebrewDate,
            generatedAt: Date()
        )
    }
}
