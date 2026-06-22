# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Settings window now has a four-tab layout: **General** (core
  behaviour preferences), **Power** (display sleep, power adapter,
  and battery preferences), **Keyboard** (global toggle shortcut),
  and **About** (app version, description, GitHub link,
  Check for Updates).
- Global toggle shortcut in Settings → Keyboard. By default the
  shortcut is `⌘⇧C` (Command+Shift+C); the user can record any
  key combination and disable/enable the shortcut from the
  Keyboard tab. The shortcut is registered via Carbon's
  `RegisterEventHotKey` API so it works system-wide, even when
  Caffeine is not the frontmost app, and does not require
  Accessibility permission.
- "Check for Updates" moved from the menu bar item to the About tab.
- "Start at login" preference in Settings → General. When enabled,
  Caffeine registers itself with `SMAppService.mainApp` so it
  launches automatically on user login. Default is off.
- "Allow display to sleep" preference in Settings → Power. When
  enabled (the default), Caffeine holds only the system idle
  assertion so the display can sleep on its normal schedule while
  the Mac stays awake. When disabled, Caffeine holds the stricter
  display assertion that also keeps the display awake.
- "Activate when power adapter is connected" preference in
  Settings → Power. When enabled, Caffeine automatically activates
  when a power adapter is connected. Default is off.
- "Deactivate when power adapter is disconnected" preference in
  Settings → Power. When enabled, Caffeine automatically
  deactivates when the power adapter is disconnected. Default is off.
- "Deactivate on low battery" preference in Settings → Power with
  a configurable threshold slider (5–50 %, default 20 %). When
  enabled, Caffeine automatically deactivates when the internal
  battery drops below the threshold. Desktop Macs without a battery
  are unaffected.

### Fixed

- "Allow display to sleep", "Activate when power adapter is
  connected", "Deactivate when power adapter is disconnected",
  "Deactivate on low battery" toggles and the low-battery threshold
  slider could not be toggled/adjusted. Their custom `Binding`
  closures called view-model methods without first writing the new
  value back to `SettingsModel`, so the getter always returned the
  stale value and SwiftUI reverted the control.
- "Default duration" preference in Settings → General now takes
  effect within the current session, not only on the next app
  launch. Previously, `CaffeineApp` and `CaffeineViewModel` each
  constructed their own `SettingsModel`, so a Picker change in
  the Settings window updated the app's instance while the view
  model read the stale copy. `CaffeineViewModel` now receives the
  shared instance via injection, and the parameter is non-optional
  to prevent the same mistake from recurring.

### Removed

- First-launch pop-up of the Settings window (and its associated
  "Show this message when starting Caffeine" preference). Users
  open Settings themselves from the menu bar via
  `Settings…`.
- Suppression of the keyboard focus ring on the Settings tab bar
  and on form controls; SwiftUI's default focus indicator is now
  shown.

### Changed

- Menu bar item label renamed from `Preferences…` to `Settings…`
  in every supported language. Updated across all 14
  `Localizable.strings` files (en, zh-Hans, de, ja, ko, es, fr,
  it, nl, pt, pt-BR, ru, uk) and the source string in
  `MenuBarContentView.swift`.
- Renamed the view files in `Classes/Views/` to follow the
  `*View` convention: `GeneralSettings` / `AboutSettings` /
  `MenuBarContent` are now `GeneralSettingsView` /
  `AboutSettingsView` / `MenuBarContentView`.
- Menu bar `inactive` icon is now a coffee bean (with a central
  groove) instead of an empty cup, so the two states are clearly
  different shapes rather than "full cup vs empty cup" variants.
- Settings window minimum width and default size widened from
  380pt to 440pt so toggles and labels no longer hug the edge.
- Settings window now uses the native `Settings { TabView { Tab { ... } } }` API (macOS 14+), removing the custom tab buttons and the `SettingsTabButtonStyle` workaround. Tab theming now follows the system appearance automatically.
- All user preferences are now read and written through a single `SettingsModel` (`@Observable`), replacing scattered `UserDefaults.standard.bool(forKey:)` calls in `CaffeineViewModel` and per-view `@AppStorage` bindings.
- `AppDelegate` no longer observes `NSApp.effectiveAppearance` to force-update window appearance; system default behaviour is relied upon instead.
- The "About" tab now uses `Form` with `.formStyle(.grouped)` for visual consistency with the "General" tab.

## [1.6.5] - 2026-06-16

### Changed

- Improved Ukrainian translation.

### Fixed

- Timer no longer stays active and shows negative seconds after the Mac sleeps past the activation period.
- Right-click on the menu bar icon no longer fails to show the context menu on macOS 27. On macOS 27 the system no longer delivers right-mouse events to `NSStatusBarButton` at the AppKit layer, so the context menu is now intercepted via a session-level `CGEventTap`. This requires the user to grant Caffeine accessibility permission on first run (System Settings → Privacy & Security → Accessibility).

## [1.6.3] - 2026-01-26

### Added

- Ukrainian translation.

### Fixed

- Activity simulation now properly resets the system idle timer.

## [1.6.2] - 2025-12-14

### Added

- Optional "Keep apps active" preference that simulates activity to prevent apps from going idle.

### Fixed

- Corrected the Control-click instruction symbol.

## [1.6.1] - 2025-11-13

### Fixed

- Menu bar icon tinting.

## [1.6.0] - 2025-11-12

### Added

- Rewritten in SwiftUI.
- Automatic update reminders via Sparkle.
- App accent color and category.

### Changed

- Updated the icon for Tahoe with a static gradient.
- Repositioned menu items.

### Fixed

- Entitlements.
- Deprecation warnings.
- Typo on the preferences screen.

## [1.5.3] - 2025-06-25

### Added

- Control-click is now treated the same as a right-click.

## [1.5.2] - 2025-05-23

### Fixed

- Default duration is now respected.

## [1.5.1] - 2025-03-03

### Fixed

- Preferences window no longer appears unexpectedly on launch.

## [1.5.0] - 2025-01-22

### Added

- Automatic updates via Sparkle.

### Changed

- Migrated the project to Swift.
- Updated for macOS Sequoia.

## [1.4.0] - 2023-10-17

### Changed

- Updated icon for macOS Sonoma.

## [1.3.0] - 2023-10-17

### Added

- Japanese localization, plus localizations with dynamic layout support.
- Preference to deactivate Caffeine when the device is manually put to sleep.
- Sonoma-styled app icon.
- GitHub sponsorship support.

### Changed

- Refactored the preferences window.

### Fixed

- Deactivating the app now reliably releases the system sleep assertion.
- App icon drop shadow.
- View autoresizing.

## [1.1.3] - 2020-05-12

### Added

- Initial public release.
