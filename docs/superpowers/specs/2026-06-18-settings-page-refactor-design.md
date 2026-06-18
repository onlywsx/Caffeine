# Settings Page Refactor — Design

**Date:** 2026-06-18
**Status:** Approved (pending user review of written spec)
**Scope:** Restructure the Settings window to use the native `Settings { TabView { Tab } }` API and centralise all preferences behind a single `SettingsModel`.

## Motivation

The current Settings window was assembled by hand:

- `PreferencesView.swift` hosts a custom `HStack` of `SettingsTabButton` views plus an `if/else` for tab content.
- `SettingsTabButtonStyle.swift` defines the `SettingsTab` enum and the custom button view, motivated by the fact that `Picker(.segmented)` and the new `Tab` API cache their appearance on macOS 15+ and do not follow system theme changes in real time.
- `AppDelegate.swift` adds a KVO observer on `NSApp.effectiveAppearance` that force-updates every open window's `appearance` whenever the system theme changes.
- `GeneralSettingsView` mixes `@AppStorage` bindings with a direct call into `CaffeineViewModel.updateActivitySimulation(enabled:)` for the `Keep apps active` toggle.
- `AboutView` uses a hand-built `VStack` while `GeneralSettingsView` uses `Form(.grouped)` — the two tabs do not share a visual language.

The user requested a "latest best-practice" rewrite: use the native macOS `Settings { TabView }` API, drop the custom tab workaround, and centralise preference reads/writes.

## Goals

1. **Native macOS Settings chrome.** Use `Settings { TabView { Tab { ... } } }` (macOS 14+) so the system owns tab layout, title bar, sizing, and appearance following.
2. **Single source of truth for preferences.** Introduce a `@Observable` `SettingsModel` that wraps the existing `UserDefaults` keys. `CaffeineViewModel`, the Settings tabs, and `MenuBarContent` (if needed) all read from it.
3. **Visual consistency between tabs.** Both `GeneralSettings` and `AboutSettings` use `Form` + `.formStyle(.grouped)`.
4. **Simpler AppDelegate.** Remove the `NSApp.effectiveAppearance` KVO observer; trust the system default.

## Non-Goals

- No new user-facing preferences (no `Display sleep override`, no `Start at login`, etc.). Scope is structural only.
- No changes to `SleepPreventionManager`, `ActivitySimulator`, or `MenuBarContent`'s visible behaviour.
- No migration of `UserDefaults` keys — keys and their semantic meaning stay identical.

## File-Level Changes

### New Files

| Path | Purpose |
|------|---------|
| `src/Caffeine/Classes/Models/SettingsModel.swift` | `@Observable` wrapper around the four existing `UserDefaults` keys, with explicit `persist(_:)` for writes. |
| `src/Caffeine/Classes/Views/GeneralSettings.swift` | Replaces `GeneralSettingsView.swift`. `Form(.grouped)` content bound to `SettingsModel`. |
| `src/Caffeine/Classes/Views/AboutSettings.swift` | Replaces `AboutView.swift`. Same `Form(.grouped)` style with two sections (metadata, actions). |

### Modified Files

| Path | Change |
|------|--------|
| `src/Caffeine/Classes/ViewModels/CaffeineViewModel.swift` | Drop the `PreferenceKeys` enum (moved to `SettingsModel.swift`). Inject a `SettingsModel` in `init`. Replace `UserDefaults.standard.bool/integer(forKey:)` calls with `self.settings.xxx` reads. `updateActivitySimulation(enabled:)` now also writes through the model. |
| `src/Caffeine/Classes/CaffeineApp.swift` | Add `@State private var settings = SettingsModel()`. Replace the `Settings { PreferencesView(...) }` body with a `TabView` containing two `Tab` children (`General`, `About`). Apply `frame(minWidth: 480, minHeight: 360)` at the `TabView` level. |
| `src/Caffeine/Classes/AppDelegate.swift` | Remove the `appearanceObserver` KVO block. The whole file becomes a one-liner: `NSApp.setActivationPolicy(.accessory)`. |
| `CHANGELOG.md` | Append a `### Changed` block under `## [Unreleased]`. |

### Deleted Files

| Path | Reason |
|------|--------|
| `src/Caffeine/Classes/Views/PreferencesView.swift` | Replaced by the inline `TabView` in `CaffeineApp`. |
| `src/Caffeine/Classes/Views/SettingsTabButtonStyle.swift` | Custom tab buttons fully retired; the file's name also no longer matches its contents. |
| `src/Caffeine/Classes/Views/GeneralSettingsView.swift` | Renamed to `GeneralSettings.swift`. |
| `src/Caffeine/Classes/Views/AboutView.swift` | Renamed to `AboutSettings.swift`. |

The project uses Xcode 16 File System Synchronized Groups (`src/Caffeine/Classes/`), so file creation, renaming, and deletion are picked up by Xcode automatically — no project file edits are required.

## `SettingsModel` Design

```swift
@MainActor
@Observable
final class SettingsModel {
    var defaultDuration: Int
    var activateAtLaunch: Bool
    var deactivateOnManualSleep: Bool
    var keepAppsActive: Bool

    @ObservationIgnored
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.defaultDuration = defaults.integer(forKey: PreferenceKeys.defaultDuration)
        self.activateAtLaunch = defaults.bool(forKey: PreferenceKeys.activateAtLaunch)
        self.deactivateOnManualSleep = defaults.bool(forKey: PreferenceKeys.deactivateOnManualSleep)
        self.keepAppsActive = defaults.bool(forKey: PreferenceKeys.keepAppsActive)
    }

    func persist(_ key: String) {
        let value: Any
        switch key {
        case PreferenceKeys.defaultDuration:        value = self.defaultDuration
        case PreferenceKeys.activateAtLaunch:        value = self.activateAtLaunch
        case PreferenceKeys.deactivateOnManualSleep: value = self.deactivateOnManualSleep
        case PreferenceKeys.keepAppsActive:          value = self.keepAppsActive
        default:
            DZLog("SettingsModel.persist: unknown key \(key)")
            return
        }
        self.defaults.set(value, forKey: key)
    }
}
```

### Design Rationale

- **`@Observable` (not `@AppStorage`).** Lets us inject `UserDefaults` for tests, centralises key handling, and avoids four separate `@AppStorage` declarations that each duplicate the key.
- **No automatic persistence in setters.** The view layer explicitly decides when to write — for most toggles, `.onChange(of:)` is the natural seam; for the `Keep apps active` toggle, the write is paired with a `viewModel.updateActivitySimulation` call so they happen atomically. This avoids the boilerplate of a per-property computed setter.
- **`@MainActor`.** All UI-affecting state lives on the main actor, matching `CaffeineViewModel`.
- **`PreferenceKeys` enum moves with it.** Since every read of a preference now goes through `SettingsModel`, the enum has one home and one set of readers. `CaffeineViewModel` no longer references it directly.
- **The `switch` in `persist(_:)` is bounded.** Four cases today. If the number of preferences grows past ~6, this is the signal to refactor to per-property setters or to a keyed dictionary; not yet.

## `CaffeineViewModel` Changes

1. Add `@ObservationIgnored private let settings: SettingsModel` and accept it in `init` (default `SettingsModel()`).
2. Delete the `PreferenceKeys` enum at the bottom of the file.
3. Replace each `UserDefaults.standard.<type>(forKey:)` call with the corresponding `self.settings.xxx` read.
4. Update `updateActivitySimulation(enabled:)` to:
   - Set `self.settings.keepAppsActive = enabled` and call `self.settings.persist(PreferenceKeys.keepAppsActive)` if it changed.
   - Keep the existing `requestPermission` / `startMonitoring` / `stopMonitoring` logic unchanged.
5. Keep the existing Combine `cancellables` for `NSWorkspace.willSleepNotification` / `didWakeNotification` — these are long-lived streams and Combine is the right tool here. (The "Avoid Combine unless specifically needed" rule in `AGENTS.md` explicitly allows this.)

## Settings View Structure

### `GeneralSettings`

```swift
struct GeneralSettings: View {
    @Bindable var viewModel: CaffeineViewModel
    @Bindable var settings: SettingsModel

    var body: some View {
        Form {
            Section { /* default-duration Picker(.menu) */ }
            Section { /* activateAtLaunch, deactivateOnManualSleep Toggles */ }
            Section {
                Toggle("Keep apps active", isOn: Binding(
                    get: { self.settings.keepAppsActive },
                    set: { newValue in
                        self.settings.keepAppsActive = newValue
                        self.settings.persist(PreferenceKeys.keepAppsActive)
                        self.viewModel.updateActivitySimulation(enabled: newValue)
                    }
                ))
                Text("Prevents apps from becoming inactive and the screen saver from starting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: self.settings.defaultDuration) { _, _ in
            self.settings.persist(PreferenceKeys.defaultDuration)
        }
        .onChange(of: self.settings.activateAtLaunch) { _, _ in
            self.settings.persist(PreferenceKeys.activateAtLaunch)
        }
        .onChange(of: self.settings.deactivateOnManualSleep) { _, _ in
            self.settings.persist(PreferenceKeys.deactivateOnManualSleep)
        }
    }
}
```

Removals vs the current `GeneralSettingsView`:
- `scrollContentBackground(.hidden)` and the `padding` modifiers — `Form(.grouped)` already provides the correct chrome.
- `@AppStorage` declarations — replaced by the bound `SettingsModel`.

### `AboutSettings`

Two sections inside a `Form(.grouped)`:
- Section 1: app icon, name, version, short description — centred, `VStack` with `frame(maxWidth: .infinity)`.
- Section 2: `View on GitHub` button and `Check for Updates...` button.

This matches the visual language of `GeneralSettings` while keeping the About content centred within its section.

### `CaffeineApp` Settings scene

```swift
Settings {
    TabView {
        Tab(String(localized: "General"), systemImage: "gearshape") {
            GeneralSettings(viewModel: self.viewModel, settings: self.settings)
        }
        Tab(String(localized: "About"), systemImage: "info.circle") {
            AboutSettings(updater: self.updater)
        }
    }
    .frame(minWidth: 480, minHeight: 360)
}
```

- `minHeight` raised from 300 to 360 to accommodate `Form(.grouped)` chrome inside each tab.
- `Tab`'s `systemImage:` is the macOS 14+ initializer that includes a sidebar-style icon — this replaces the manually drawn icon in the old custom button.

## `AppDelegate` After

```swift
import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
```

The `NSApp.effectiveAppearance` KVO observer is removed. The system default behaviour is relied upon. If a regression appears, the previous implementation is recoverable from git history.

## Risks

1. **Theme-following regression.** The custom tab buttons were specifically built to work around a macOS 15+ bug where `Tab` and `Picker(.segmented)` cache their appearance at window creation. The user accepted the risk of relying on system default behaviour. The previous `AppDelegate` KVO code is the documented fallback.
2. **macOS 14 floor.** `Tab(_:systemImage:)` is a macOS 14+ API. The current deployment target is macOS 13.5. The implementation plan must verify this at build time; if it fails, either raise the deployment target to 14.0 or wrap the `Settings { TabView }` block in `if #available(macOS 14, *)` with a `TabView { ... }.tabViewStyle(...)` fallback for 13.5.
3. **Swift 6 concurrency.** `SettingsModel` is `@MainActor` and `persist` mutates `UserDefaults` (thread-safe). No `Sendable` concerns.

## CHANGELOG Entry (to be appended under `## [Unreleased]`)

```markdown
### Changed

- Settings window now uses the native `Settings { TabView { Tab { ... } } }`
  API (macOS 14+), removing the custom tab buttons and the
  `SettingsTabButtonStyle` workaround. Tab theming now follows the
  system appearance automatically.
- All user preferences are now read and written through a single
  `SettingsModel` (`@Observable`), replacing scattered
  `UserDefaults.standard.bool(forKey:)` calls in `CaffeineViewModel`
  and per-view `@AppStorage` bindings.
- `AppDelegate` no longer observes `NSApp.effectiveAppearance` to
  force-update window appearance; system default behaviour is
  relied upon instead.
- The "About" tab now uses `Form` with `.formStyle(.grouped)` for
  visual consistency with the "General" tab.
```

## Verification Plan

1. `xcodebuild -scheme "Caffeine" -destination "platform=macOS" build` succeeds.
2. `swiftformat .` reports no diff.
3. Manual launch:
   - Open Settings from the menu bar (`Preferences...`).
   - Switch between General and About tabs; the active tab indicator updates instantly.
   - Toggle "Activate when starting Caffeine" in General; quit and relaunch the app; the setting is remembered.
   - Toggle system appearance (System Settings → Appearance) between Light and Dark; the Settings window tab bar updates in real time.
   - Click "Check for Updates..." in About; the Sparkle update sheet appears.
4. If the `Tab` API is unavailable on the build's SDK, follow risk #2.

## Out of Scope (Confirmed with User)

- Adding new preferences (e.g. `Display sleep override`, `Start at login`).
- Any change to `MenuBarContent`, `SleepPreventionManager`, `ActivitySimulator`.
- Any change to the menu bar icon or the activation flow.
