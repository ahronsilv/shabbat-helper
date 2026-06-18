# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Shabbat Helper is a SwiftUI iOS app (MVVM) that shows Shabbat candle-lighting / Havdalah times, the weekly parsha, and the Hebrew date for the user's current location and saved cities, using the [Hebcal](https://www.hebcal.com/) Shabbat API.

- Deployment target: iOS 26.5+, Swift 5.0, Xcode 26+
- Bundle id: `org.fd14348881ba6ec3.shabbat-helper`

## Commands

```sh
# Build
xcodebuild -project shabbat-helper.xcodeproj -scheme shabbat-helper build

# All tests (unit + UI)
xcodebuild -project shabbat-helper.xcodeproj -scheme shabbat-helper -destination 'platform=iOS Simulator,name=iPhone 16' test

# Single test class or method
xcodebuild ... test -only-testing:shabbat-helperTests/shabbat_helperTests
xcodebuild ... test -only-testing:shabbat-helperTests/shabbat_helperTests/testStoredTimeFormatPreferencePreservesSavedChoice
```

## Architecture

The data flow is: **Services** (network, location, persistence) → **ViewModels** (`@MainActor ObservableObject`, expose state enums) → **Views** (SwiftUI). Two parallel UI surfaces exist:

- `HomeView` / `HomeViewModel` — the current main screen: a current-location row plus a reorderable/deletable list of favorites. Each row fetches independently and carries its own `RowStatus` (`.loading/.loaded/.empty/.error`).
- `ShabbatTimesView` / `ShabbatTimesViewModel` — single-location detail flow with a `ViewState` enum.

### Services and dependency injection

Every service sits behind a protocol (`HebcalServicing`, `LocationServicing`, `LocationStoring`, `HTTPClient`) so ViewModels can be unit-tested with fakes. ViewModels have **two initializers**: a no-arg one that wires up the real concrete services, and a second one that injects dependencies. When adding a service, follow this protocol + dual-init pattern.

- `HebcalService` builds the Hebcal URL from a `SavedLocation` and a target date, decodes `HebcalResponse`, and reduces it to a `ShabbatTimes` summary by filtering `items` by `category` (`candles`, `havdalah`, `parashat`). `fetchUpcomingShabbatTimes` automatically rolls forward one week if this week's candle-lighting has already passed. Latitude/longitude are formatted with `en_US_POSIX` to avoid locale decimal separators.
- `LocationStore` persists to `UserDefaults` as JSON. It de-duplicates favorites via `SavedLocation.matchesPlace` (name + ~0.01° coordinate tolerance) and runs a one-time migration of the legacy single `selectedLocation` into the `favoriteLocations` array (guarded by `didMigrateFavoriteLocations`).

### Localization (important)

The app ships 5 localizations under `shabbat-helper/*.lproj/`: **en, he, ru, fr, am**. When adding user-facing strings:

- Add the key to **every** `Localizable.strings` and use `String(localized: "key")` in code (errors use this too).
- The Hebcal API request language is mapped separately in `HebcalLanguageMapper` (e.g. `he` → `he-x-NoNikud`; `en`/`am` → no `lg` param). Update it if adding a language Hebcal supports.
- Hebrew requires RTL support — verify layout when touching views.

### Formatting / preferences

`Formatters.swift` holds `TimeFormatPreference` (the 12h/24h toggle, stored in `UserDefaults` under `uses24HourTime`, defaulting to the locale's hour cycle) and `DisplayFormatters` for all time/date/coordinate display. Route formatting through these rather than ad-hoc `DateFormatter`s.

## Testing notes

Unit tests in `shabbat-helperTests/` create an isolated `UserDefaults(suiteName:)` per test (see `setUpWithError`) so store/preference tests don't touch real defaults — preserve this when adding persistence tests.
