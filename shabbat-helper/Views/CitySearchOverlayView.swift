import SwiftUI
import UIKit

struct CitySearchOverlayView: View {
    @StateObject private var viewModel = CitySearchViewModel()
    @FocusState private var isSearchFocused: Bool
    @State private var previewLocation: SavedLocation?
    @State private var hasHandledInitialFocus = false
    @State private var keyboardOverlap: CGFloat = 0

    let savedLocations: [SavedLocation]
    let onAdd: (SavedLocation) async -> Bool
    let onDismiss: () -> Void

    private static let searchBarHeight: CGFloat = 56

    var body: some View {
        GeometryReader { proxy in
            let overlayWidth = overlayWidth(in: proxy)
            let searchBarWidth = max(0, searchBarContainerWidth(in: proxy) - 40)

            ZStack(alignment: .bottom) {
                Color.black
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissKeyboardOnly()
                    }

                if let previewLocation {
                    CitySearchPreviewView(
                        location: previewLocation,
                        isAlreadySaved: isAlreadySaved(previewLocation),
                        onAdd: onAdd,
                        onClose: {
                            self.previewLocation = nil
                            isSearchFocused = true
                        },
                        onDone: onDismiss
                    )
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    searchContent(bottomPadding: searchContentBottomPadding(in: proxy))
                        .frame(width: overlayWidth)
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                dismissKeyboardOnly()
                            }
                        )

                    HStack {
                        activeSearchBar
                            .frame(width: searchBarWidth, height: Self.searchBarHeight)
                    }
                    .frame(width: overlayWidth)
                    .padding(.bottom, searchBarBottomPadding(in: proxy))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: overlayWidth, height: proxy.size.height, alignment: .bottom)
            .clipped()
            .ignoresSafeArea()
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
                updateKeyboardOverlap(from: notification, in: proxy)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
                clearKeyboardOverlap(from: notification)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            activateSearchIfNeeded()
        }
        .onDisappear {
            isSearchFocused = false
            dismissKeyboard()
        }
    }

    private func overlayWidth(in proxy: GeometryProxy) -> CGFloat {
        guard keyboardOverlap > 0 else {
            return proxy.size.width
        }

        guard let windowWidth = activeWindowBounds?.width, windowWidth > 0 else {
            return proxy.size.width
        }

        return min(proxy.size.width, windowWidth)
    }

    private func searchBarContainerWidth(in proxy: GeometryProxy) -> CGFloat {
        guard let windowWidth = activeWindowBounds?.width, windowWidth > 0 else {
            return proxy.size.width
        }

        return min(proxy.size.width, windowWidth)
    }

    private var activeWindowBounds: CGRect? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .bounds
    }

    private func searchContent(bottomPadding: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                addressSuggestionsSection

                switch viewModel.state {
                case .idle:
                    SearchOverlayHint()
                case .loading:
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text("searching_cities")
                            .foregroundStyle(.white.opacity(0.68))
                    }
                    .padding(.top, 28)
                case .results:
                    ForEach(viewModel.results) { location in
                        Button {
                            openPreview(for: location)
                        } label: {
                            SearchOverlayResultRow(
                                location: location,
                                isAlreadySaved: isAlreadySaved(location)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                case .noResults:
                    SearchOverlayMessage(
                        systemImage: "mappin.slash",
                        title: String(localized: "no_results"),
                        message: String(localized: "no_results_message")
                    )
                case .error(let message):
                    SearchOverlayMessage(
                        systemImage: "exclamationmark.triangle",
                        title: String(localized: "search_failed"),
                        message: message
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 90)
            .padding(.bottom, bottomPadding)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private var addressSuggestionsSection: some View {
        if !viewModel.addressSuggestions.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("suggestions")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.38))

                ForEach(viewModel.addressSuggestions) { suggestion in
                    Button {
                        openPreview(for: suggestion.location)
                    } label: {
                        SearchOverlaySuggestionRow(
                            suggestion: suggestion,
                            isAlreadySaved: isAlreadySaved(suggestion.location)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var activeSearchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            TextField(
                "",
                text: $viewModel.query,
                prompt: Text("city_or_address")
                    .foregroundStyle(.white.opacity(0.5))
            )
            .textFieldStyle(.plain)
            .font(.body)
            .foregroundStyle(.white)
            .tint(.blue)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .focused($isSearchFocused)
            .multilineTextAlignment(viewModel.query.hasRightToLeftBaseDirection ? .trailing : .leading)
            .frame(maxWidth: .infinity, minHeight: 44)
            .clipped()
            .layoutPriority(1)
            .onChange(of: viewModel.query) { _, _ in
                viewModel.scheduleSearch()
            }
            .onSubmit {
                isSearchFocused = false
            }

            Button(action: dismissSearch) {
                Image(systemName: "xmark")
                    .font(.headline.weight(.semibold))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.1), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("close_city_search")
            .fixedSize()
        }
        .padding(.leading, 16)
        .padding(.trailing, 11)
        .frame(maxWidth: .infinity, minHeight: Self.searchBarHeight)
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
    }

    private func searchBarBottomPadding(in proxy: GeometryProxy) -> CGFloat {
        guard keyboardOverlap > 0 else {
            return proxy.safeAreaInsets.bottom + 18
        }

        return keyboardOverlap + 8
    }

    private func searchContentBottomPadding(in proxy: GeometryProxy) -> CGFloat {
        Self.searchBarHeight + searchBarBottomPadding(in: proxy) + proxy.safeAreaInsets.bottom + 32
    }

    private func updateKeyboardOverlap(from notification: Notification, in proxy: GeometryProxy) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }

        let overlayFrame = proxy.frame(in: .global)
        let newKeyboardOverlap = max(0, overlayFrame.maxY - keyboardFrame.minY)

        withAnimation(keyboardAnimation(from: notification)) {
            keyboardOverlap = newKeyboardOverlap
        }
    }

    private func clearKeyboardOverlap(from notification: Notification) {
        withAnimation(keyboardAnimation(from: notification)) {
            keyboardOverlap = 0
        }
    }

    private func keyboardAnimation(from notification: Notification) -> Animation {
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.22
        let curveValue = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int
        let curve = curveValue.flatMap(UIView.AnimationCurve.init(rawValue:))

        switch curve {
        case .easeInOut:
            return .easeInOut(duration: duration)
        case .easeIn:
            return .easeIn(duration: duration)
        case .easeOut:
            return .easeOut(duration: duration)
        case .linear:
            return .linear(duration: duration)
        case nil:
            return .easeOut(duration: duration)
        @unknown default:
            return .easeOut(duration: duration)
        }
    }

    private func activateSearchIfNeeded() {
        guard !hasHandledInitialFocus else { return }
        hasHandledInitialFocus = true
        viewModel.loadAddressSuggestionsIfNeeded()
        isSearchFocused = true
    }

    private func isAlreadySaved(_ location: SavedLocation) -> Bool {
        savedLocations.contains { $0.matchesPlace(location) }
    }

    private func openPreview(for location: SavedLocation) {
        isSearchFocused = false

        withAnimation(.snappy(duration: 0.24)) {
            previewLocation = location
        }
    }

    private func dismissSearch() {
        isSearchFocused = false
        dismissKeyboard()
        onDismiss()
    }

    private func dismissKeyboardOnly() {
        isSearchFocused = false
        dismissKeyboard()
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

}

private extension String {
    var hasRightToLeftBaseDirection: Bool {
        for scalar in unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                continue
            }

            if scalar.isRightToLeftScript {
                return true
            }

            if CharacterSet.letters.contains(scalar) {
                return false
            }
        }

        return false
    }
}

private extension Unicode.Scalar {
    var isRightToLeftScript: Bool {
        switch value {
        case 0x0590...0x08FF, 0xFB1D...0xFEFC:
            return true
        default:
            return false
        }
    }
}

private struct SearchOverlayResultRow: View {
    let location: SavedLocation
    let isAlreadySaved: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.82))

            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(location.detail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.56))
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            if isAlreadySaved {
                Label("already_added", systemImage: "checkmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.white.opacity(0.52))
                    .accessibilityLabel("already_added")
            } else {
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.34))
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct SearchOverlaySuggestionRow: View {
    let suggestion: CitySearchViewModel.AddressSuggestion
    let isAlreadySaved: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: suggestion.label == String(localized: "home_suggestion_label") ? "house.fill" : "briefcase.fill")
                .font(.title3.weight(.semibold))
                .frame(width: 30)
                .foregroundStyle(.white.opacity(0.86))

            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.label)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(suggestion.location.nameAndDetail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.56))
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            if isAlreadySaved {
                Label("already_added", systemImage: "checkmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.white.opacity(0.52))
                    .accessibilityLabel("already_added")
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct SearchOverlayHint: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.white.opacity(0.46))

            Text("search_for_city_title")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            Text("search_hint_message")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.48))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .padding(.horizontal, 16)
    }
}

private struct SearchOverlayMessage: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white.opacity(0.44))

            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.48))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(.horizontal, 16)
    }
}

private extension SavedLocation {
    var nameAndDetail: String {
        detail.isEmpty || detail == name ? name : "\(name), \(detail)"
    }
}
