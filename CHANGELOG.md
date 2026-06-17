# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Settings window now has a two-tab layout: **General** (existing
  preferences) and **About** (app version, description, GitHub
  link, Check for Updates).
- "Check for Updates" moved from the menu bar item to the About tab.

### Fixed

- Settings tab bar now follows the system light/dark theme. The
  built-in `TabView` segmented control on macOS 14.6 cached its
  appearance at window creation; the tab bar is now a `Picker`
  with `.segmented` style, which SwiftUI re-evaluates on
  `colorScheme` change.

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
