import SwiftUI
import UIKit

struct CitySearchPreviewView: View {
    private enum AddState {
        case idle
        case adding
        case alreadyAdded
    }

    @AppStorage(TimeFormatPreference.uses24HourTimeKey) private var uses24HourTime = TimeFormatPreference.defaultUses24HourTime
    @StateObject private var viewModel: ShabbatTimesViewModel
    @State private var hasLoaded = false
    @State private var addState: AddState = .idle

    let location: SavedLocation
    let isAlreadySaved: Bool
    let onAdd: (SavedLocation) async -> Bool
    let onClose: () -> Void
    let onDone: () -> Void

    private var isAdding: Bool {
        addState == .adding
    }

    private var cannotAdd: Bool {
        isAlreadySaved || addState == .alreadyAdded
    }

    init(
        location: SavedLocation,
        isAlreadySaved: Bool,
        onAdd: @escaping (SavedLocation) async -> Bool,
        onClose: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) {
        self.location = location
        self.isAlreadySaved = isAlreadySaved
        self.onAdd = onAdd
        self.onClose = onClose
        self.onDone = onDone
        _viewModel = StateObject(wrappedValue: ShabbatTimesViewModel(initialLocation: location))
    }

    var body: some View {
        GeometryReader { proxy in
            let safeAreaInsets = activeWindowSafeAreaInsets

            VStack(spacing: 0) {
                previewToolbar(topSafeArea: safeAreaInsets.top)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PreviewHeader(location: location)

                        previewContent

                        if cannotAdd {
                            AlreadyAddedNotice()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                    .padding(.bottom, safeAreaInsets.bottom + 34)
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
        }
        .foregroundStyle(.white)
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            await viewModel.load()
        }
    }

    private var activeWindowSafeAreaInsets: UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets ?? .zero
    }

    private func previewToolbar(topSafeArea: CGFloat) -> some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.title2.weight(.semibold))
                    .frame(width: 56, height: 56)
                    .background(Color.white.opacity(0.1), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close city preview")

            Spacer()

            if cannotAdd {
                Color.clear
                    .frame(width: 56, height: 56)
            } else {
                Button {
                    Task {
                        await addCity()
                    }
                } label: {
                    if isAdding {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 56, height: 56)
                    } else {
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .frame(width: 56, height: 56)
                            .background(Color.white.opacity(0.92), in: Circle())
                            .foregroundStyle(.black)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isAdding)
                .accessibilityLabel("Add city")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, topSafeArea + 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var previewContent: some View {
        switch viewModel.state {
        case .initialLoading, .requestingLocation, .fetchingTimes:
            PreviewLoadingCard()
        case .loaded(let times, _):
            PreviewCandleCard(times: times, uses24HourTime: uses24HourTime)
            PreviewDetailsCard(times: times, location: location, uses24HourTime: uses24HourTime)
        case .locationDenied:
            PreviewMessageCard(
                systemImage: "location.slash",
                title: "Location Access Is Off",
                message: "This city can still be previewed from search, but current-location access is unavailable."
            )
        case .empty:
            PreviewMessageCard(
                systemImage: "calendar.badge.exclamationmark",
                title: "No Candle Lighting Found",
                message: "Try another nearby city or refresh in a moment."
            )
        case .error(let message, _):
            PreviewMessageCard(
                systemImage: "wifi.exclamationmark",
                title: "Could not Update Times",
                message: message
            )
        }
    }

    private func addCity() async {
        guard !cannotAdd else { return }

        addState = .adding
        let didAdd = await onAdd(location)

        if didAdd {
            onDone()
        } else {
            addState = .alreadyAdded
        }
    }
}

private struct PreviewHeader: View {
    let location: SavedLocation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(location.name)
                .font(.system(size: 50, weight: .bold, design: .default))
                .lineLimit(2)
                .minimumScaleFactor(0.68)

            Text(location.detail)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.52))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PreviewCandleCard: View {
    let times: ShabbatTimes
    let uses24HourTime: Bool

    var body: some View {
        let candleDate = times.candleLighting.dateValue

        VStack(alignment: .leading, spacing: 14) {
            Label("Candle Lighting", systemImage: "flame.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))

            Text(candleDate.map { DisplayFormatters.time($0, timeZone: times.timeZone, uses24HourTime: uses24HourTime) } ?? "Time unavailable")
                .font(.system(size: 66, weight: .thin, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .monospacedDigit()

            Text(candleDate.map { DisplayFormatters.day($0, timeZone: times.timeZone) } ?? "Date unavailable")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct PreviewDetailsCard: View {
    let times: ShabbatTimes
    let location: SavedLocation
    let uses24HourTime: Bool

    var body: some View {
        VStack(spacing: 0) {
            PreviewDetailRow(
                icon: "mappin.and.ellipse",
                title: "Region",
                value: times.locationDetail
            )

            Divider().overlay(.white.opacity(0.18))

            PreviewDetailRow(
                icon: "sparkles",
                title: "Havdalah",
                value: times.havdalah?.dateValue.map { DisplayFormatters.time($0, timeZone: times.timeZone, uses24HourTime: uses24HourTime) } ?? "Not available"
            )

            Divider().overlay(.white.opacity(0.18))

            PreviewDetailRow(
                icon: "book.closed.fill",
                title: "Parsha",
                value: times.parsha?.title.replacingOccurrences(of: "Parashat ", with: "") ?? times.candleLighting.memo ?? "Not available"
            )

            Divider().overlay(.white.opacity(0.18))

            PreviewDetailRow(
                icon: "location.north.line.fill",
                title: "Coordinates",
                value: DisplayFormatters.shortCoordinate(latitude: location.latitude, longitude: location.longitude)
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct PreviewDetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.headline)
                .frame(width: 28)
                .foregroundStyle(.white.opacity(0.62))

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.56))

            Spacer(minLength: 10)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .frame(minHeight: 52)
    }
}

private struct PreviewLoadingCard: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
            Text("Fetching Candle Lighting")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding(20)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct PreviewMessageCard: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.56))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding(20)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct AlreadyAddedNotice: View {
    var body: some View {
        Label("Already added", systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.62))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityLabel("Already added")
    }
}
