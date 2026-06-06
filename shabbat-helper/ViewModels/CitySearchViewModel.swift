import Foundation
import Combine
import MapKit

@MainActor
final class CitySearchViewModel: NSObject, ObservableObject {
    enum SearchState: Equatable {
        case idle
        case loading
        case results
        case noResults
        case error(String)
    }

    struct AddressSuggestion: Identifiable, Equatable {
        let id: String
        let label: String
        let location: SavedLocation

        var title: String {
            String(
                format: String(localized: "address_suggestion_title_format"),
                label,
                location.name
            )
        }
    }

    @Published var query = ""
    @Published private(set) var addressSuggestions: [AddressSuggestion] = []
    @Published private(set) var results: [SavedLocation] = []
    @Published private(set) var state: SearchState = .idle

    private static let maxResults = 20

    private let completer: MKLocalSearchCompleter
    private var searchTask: Task<Void, Never>?
    private var resolutionTask: Task<Void, Never>?
    private var activeSearches: [MKLocalSearch] = []
    private var activeQuery = ""
    private var didRequestAddressSuggestions = false

    init(completer: MKLocalSearchCompleter = MKLocalSearchCompleter()) {
        self.completer = completer
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address]
    }

    func loadAddressSuggestionsIfNeeded() {
        guard !didRequestAddressSuggestions else { return }
        didRequestAddressSuggestions = true
        addressSuggestions = []
    }

    func scheduleSearch() {
        searchTask?.cancel()

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else {
            resetSearch()
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            self?.search(for: trimmedQuery)
        }
    }

    func submitSearch() {
        searchTask?.cancel()
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        search(for: trimmedQuery)
    }

    private func search(for text: String) {
        guard !text.isEmpty else {
            resetSearch()
            return
        }

        activeQuery = text
        results = []
        state = .loading
        resolutionTask?.cancel()
        cancelActiveSearches()
        completer.queryFragment = text
    }

    private func resetSearch() {
        activeQuery = ""
        completer.queryFragment = ""
        resolutionTask?.cancel()
        cancelActiveSearches()
        results = []
        state = .idle
    }

    private func handleCompletions(_ completions: [MKLocalSearchCompletion]) {
        let rankedCompletions = ranked(completions, for: activeQuery)
            .prefix(Self.maxResults)

        guard !rankedCompletions.isEmpty else {
            results = []
            state = .noResults
            return
        }

        resolutionTask?.cancel()
        cancelActiveSearches()

        let query = activeQuery
        resolutionTask = Task { [weak self] in
            await self?.resolve(rankedCompletions, for: query)
        }
    }

    private func resolve(_ completions: ArraySlice<MKLocalSearchCompletion>, for query: String) async {
        var resolvedLocations: [SavedLocation] = []

        for completion in completions {
            guard !Task.isCancelled, query == activeQuery else { return }

            if let location = try? await resolve(completion) {
                resolvedLocations.append(location)
                let uniqueLocations = unique(resolvedLocations)
                results = uniqueLocations
                state = uniqueLocations.isEmpty ? .loading : .results
            }
        }

        guard !Task.isCancelled, query == activeQuery else { return }

        let uniqueLocations = unique(resolvedLocations)
        results = Array(uniqueLocations.prefix(Self.maxResults))
        state = results.isEmpty ? .noResults : .results
    }

    private func resolve(_ completion: MKLocalSearchCompletion) async throws -> SavedLocation? {
        let request = MKLocalSearch.Request(completion: completion)
        request.resultTypes = .address

        let search = MKLocalSearch(request: request)
        activeSearches.append(search)
        defer {
            activeSearches.removeAll { $0 === search }
        }

        let response = try await search.start()
        return response.mapItems.compactMap { makeSavedLocation(from: $0, completion: completion) }.first
    }

    private func makeSavedLocation(from item: MKMapItem, completion: MKLocalSearchCompletion) -> SavedLocation? {
        let coordinate: CLLocationCoordinate2D
        let name: String
        let detail: String

        if #available(iOS 26.0, *) {
            coordinate = item.location.coordinate
            name = item.addressRepresentations?.cityName
                ?? item.name
                ?? completion.title
            detail = cleanedDetail(
                item.addressRepresentations?.cityWithContext,
                name: name
            )
        } else {
            coordinate = item.placemark.coordinate
            name = item.placemark.locality
                ?? item.name
                ?? completion.title
            detail = [
                item.placemark.administrativeArea,
                item.placemark.country
            ]
                .compactMap { $0 }
                .filter { $0 != name }
                .joined(separator: ", ")
        }

        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }

        let fallbackDetail = completion.subtitle.isEmpty ? TimeZone.current.identifier : completion.subtitle
        let timeZoneIdentifier = item.timeZone?.identifier ?? TimeZone.current.identifier

        return SavedLocation(
            name: name,
            detail: detail.isEmpty ? fallbackDetail : detail,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            timeZoneIdentifier: timeZoneIdentifier
        )
    }

    private func cleanedDetail(_ detail: String?, name: String) -> String {
        guard var detail = detail?.trimmingCharacters(in: .whitespacesAndNewlines), !detail.isEmpty else {
            return ""
        }

        let repeatedPrefix = "\(name), "
        if detail.hasPrefix(repeatedPrefix) {
            detail.removeFirst(repeatedPrefix.count)
        }

        return detail == name ? "" : detail
    }

    private func unique(_ locations: [SavedLocation]) -> [SavedLocation] {
        var seen = Set<String>()
        return locations.filter { location in
            let key = "\(location.name)-\(location.detail)-\(location.latitude.rounded())-\(location.longitude.rounded())"
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    private func ranked(_ completions: [MKLocalSearchCompletion], for query: String) -> [MKLocalSearchCompletion] {
        let normalizedQuery = normalized(query)

        return completions.enumerated()
            .sorted { lhs, rhs in
                let leftScore = score(lhs.element, query: normalizedQuery)
                let rightScore = score(rhs.element, query: normalizedQuery)

                if leftScore == rightScore {
                    return lhs.offset < rhs.offset
                }

                return leftScore < rightScore
            }
            .map(\.element)
    }

    private func score(_ completion: MKLocalSearchCompletion, query: String) -> Int {
        let title = normalized(completion.title)
        let subtitle = normalized(completion.subtitle)
        let combined = "\(title) \(subtitle)"

        if title.hasPrefix(query) {
            return 0
        }

        if combined.split(separator: " ").contains(where: { $0.hasPrefix(query) }) {
            return 1
        }

        if combined.contains(query) {
            return 2
        }

        return 3
    }

    private func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cancelActiveSearches() {
        activeSearches.forEach { $0.cancel() }
        activeSearches.removeAll()
    }
}

extension CitySearchViewModel: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor [weak self] in
            self?.handleCompletions(completer.results)
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.results = []
            self?.state = .error(String(localized: "search_error_city_not_found"))
        }
    }
}
