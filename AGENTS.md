# Repository Guidelines

## Project Structure & Module Organization

This is a SwiftUI iOS app managed by `shabbat-helper.xcodeproj`. App source lives under `shabbat-helper/shabbat-helper/` and is organized by responsibility:

- `Models/` contains data types such as Hebcal responses and saved locations.
- `Services/` contains external API, location, and persistence logic.
- `ViewModels/` contains observable state and presentation logic.
- `Views/` contains SwiftUI screens, overlays, and formatting helpers.
- `Assets.xcassets` stores images, colors, and app assets.

Tests live in `shabbat-helper/shabbat-helperTests/` for unit tests and `shabbat-helper/shabbat-helperUITests/` for UI automation.

## Build, Test, and Development Commands

Prefer Xcode for day-to-day work:

- Open `shabbat-helper.xcodeproj` in Xcode.
- Build with `Product > Build` or `Cmd+B`.
- Run tests with `Product > Test` or `Cmd+U`.

Equivalent command-line examples:

```sh
xcodebuild -project shabbat-helper.xcodeproj -scheme shabbat-helper build
xcodebuild -project shabbat-helper.xcodeproj -scheme shabbat-helper test
```

Use the active simulator destination from Xcode if command-line builds require an explicit `-destination`.

## Coding Style & Naming Conventions

Use SwiftUI conventions already present in the app. Keep imports simple, use 4-space indentation, prefer `let` for constants, and keep state private with `@State private var` or view-model owned properties. Name types in PascalCase, methods and properties in camelCase, and test methods with descriptive `test...` names. Avoid force unwrapping unless the value is guaranteed and the reason is obvious from context.

## Testing Guidelines

The project currently uses XCTest for both unit tests and UI tests. Add unit coverage for service, model, persistence, and formatter behavior in `shabbat_helperTests`. Add UI workflows in `shabbat_helperUITests` when user-facing navigation or launch behavior changes. Keep tests isolated; for persistence, use a unique `UserDefaults` suite per test as existing tests do.

## Commit & Pull Request Guidelines

Recent history uses short descriptive commit messages, with occasional conventional prefixes such as `refactor:`. Prefer concise messages like `Fix city search persistence` or `refactor: simplify time formatting`.

Pull requests should include a brief summary, the reason for the change, tests run, and screenshots or screen recordings for visible UI changes. Link related issues when applicable and call out any API, location-permission, or persistence behavior changes.

## Agent-Specific Instructions

Limit edits to the requested task. Do not rewrite project structure or generated Xcode files unless required. Validate Swift changes with an Xcode build or focused diagnostics before handing work back.
