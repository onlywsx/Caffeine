# Start at Login — Design

**Date:** 2026-06-21
**Status:** Approved (pending user review of written spec)
**Scope:** Add a "Start at login" preference backed by `SMAppService.mainApp`, surfaced as a toggle in the General settings tab, and exercised through a new `LoginItemService` abstraction with unit-test coverage.

## Motivation

Caffeine currently has no way to start itself when the user logs in. Users who want the app running from boot must add it to their Login Items manually via System Settings → General → Login Items.

The user has asked for:

- A **"Start at login"** toggle in the existing Settings window.
- Use the **modern, sandbox-friendly API** (`SMAppService.mainApp`, macOS 13+) instead of writing a `LaunchAgent` plist by hand.
- A **graceful error path** — if the system rejects the change, show a one-line explanation under the toggle rather than a modal alert.
- **Quiet launch** — when the app starts at login, do not pop a notification.
- **Opt-in by default** — existing users must not suddenly start launching at boot after upgrade.

The 2026-06-18 settings refactor already centralised all preference reads/writes behind `SettingsModel` and `PreferenceKeys`, so this change slots in alongside the existing `activateAtLaunch` / `keepAppsActive` toggles with the same shape.

## Goals

1. **Use `SMAppService.mainApp`.** macOS 13+ official API, sandbox-safe (no entitlement changes required). First-time enable shows the standard system authorisation prompt.
2. **Surface a single toggle** in the General settings tab labelled "Start at login", with a one-line explanation below.
3. **Default off.** New preference key defaults to `false`. Existing users keep their current behaviour.
4. **Graceful error feedback.** If `register()` / `unregister()` throws, display a one-line red message under the toggle and revert the toggle + `UserDefaults` value.
5. **Reflect system truth on launch.** If the user manually toggled the item in System Settings, `LoginItemService.refresh()` reconciles the in-app state at launch (without overwriting a preference the user already set in our app).
6. **Unit-testable service.** Introduce a `LoginItemService` protocol so the calling code never depends on the live `SMAppService`. A `FakeLoginItemService` lives next to it.

## Non-Goals

- No migration of existing `UserDefaults` keys.
- No change to the menu bar UI (`MenuBarContentView`).
- No change to `SleepPreventionManager`, `ActivitySimulator`, `CaffeineViewModel`.
- No new entitlements (sandbox stays as-is).
- No UI tests; no new test target if none exists today.

## File-Level Changes

### New Files

| Path | Purpose |
|------|---------|
| `src/Caffeine/Classes/Services/LoginItemService.swift` | `protocol LoginItemService`, `LiveLoginItemService` (wraps `SMAppService.mainApp`), `FakeLoginItemService` (in-memory, for tests), `LoginItemStatus` enum, `LoginItemError` enum. |
| `src/Caffeine/Classes/Services/LoginItemServiceTests.swift` | XCTest cases for `FakeLoginItemService` covering success paths and the underlying-error path. Only added if a test target exists in `src/Caffeine/`; otherwise the file is created and the implementation plan flags it as a follow-up. |

### Modified Files

| Path | Change |
|------|--------|
| `src/Caffeine/Classes/Models/SettingsModel.swift` | Add `var startAtLogin: Bool`. Add `case PreferenceKeys.startAtLogin = "CAStartAtLogin"`. Read it in `init`. Handle it in `persist(_:)`. |
| `src/Caffeine/Classes/Views/GeneralSettingsView.swift` | Add a new `Section` with the toggle, optional red help text, and the secondary help caption. Inject `LoginItemService`. |
| `src/Caffeine/Classes/CaffeineApp.swift` | Add `@State private var loginItem = LoginItemService.live()`. Pass it into `GeneralSettingsView`. Trigger `refresh()` once on first scene appearance. |
| `CHANGELOG.md` | Append an `### Added` block under `## [Unreleased]`. |
| `src/Caffeine/Resources/<lang>.lproj/Localizable.strings` (×14) | Add `"Start at login"`, `"Automatically start Caffeine when you log in to your Mac."`, `"Couldn't change login item setting."` for each language. |

### Deleted Files

None.

The project uses Xcode 16 File System Synchronized Groups (`src/Caffeine/Classes/`), so adding files under `src/Caffeine/Classes/Services/` is picked up by Xcode automatically.

## Architecture

```
                ┌───────────────────────┐
                │     UserDefaults       │
                │   CAStartAtLogin       │
                └───────────▲────────────┘
                            │ read / write
                ┌───────────┴────────────┐
                │     SettingsModel      │ (@Observable)
                │   startAtLogin: Bool   │
                └───────────▲────────────┘
                            │ @Bindable
                ┌───────────┴────────────┐
                │  GeneralSettingsView   │
                │  Toggle + help text    │
                └───────────▲────────────┘
                            │ on toggle change
                            │ applyStartAtLogin(_:)
                            ▼
                ┌───────────────────────┐
                │   LoginItemService     │  protocol
                │  status / refresh /   │
                │  setEnabled(_:)       │
                └───────────▲────────────┘
                            │ conforms to
              ┌─────────────┴─────────────┐
              │                           │
   LiveLoginItemService          FakeLoginItemService
   (SMAppService.mainApp)        (in-memory for tests)
```

`SettingsModel` is intentionally **not** given a reference to `LoginItemService`. Preference persistence and OS-service interaction are separate concerns; the view layer is the natural seam to call `setEnabled(_:)` after `persist(_:)`.

## `LoginItemService` Design

```swift
import Foundation

enum LoginItemStatus: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case unknown
}

enum LoginItemError: LocalizedError {
    case underlying(String)
    case userCancelled
    case unexpected(String)

    var errorDescription: String? {
        switch self {
        case .underlying:    "Couldn't change login item setting."
        case .userCancelled: "Login item change was cancelled."
        case .unexpected:    "Couldn't change login item setting."
        }
    }
}

@MainActor
protocol LoginItemService: AnyObject {
    var status: LoginItemStatus { get }
    func refresh() async
    func setEnabled(_ enabled: Bool) async throws
}

extension LoginItemService {
    static func live() -> LoginItemService { LiveLoginItemService() }
}
```

### `LiveLoginItemService`

- Wraps `SMAppService.mainApp`.
- `refresh()`:
  - Maps `SMAppService.Status.enabled` → `.enabled`.
  - `.requiresApproval` → `.requiresApproval`.
  - `.notRegistered` / `.notFound` → `.disabled`.
  - Any other case → `.unknown`.
- `setEnabled(true)`: calls `service.register()`. On `async throws` error, throws `.underlying(String(describing: error))` after mapping `CancellationError` → `.userCancelled`.
- `setEnabled(false)`: calls `service.unregister()`. Same error mapping.
- After a successful `setEnabled`, immediately calls `refresh()` so `status` reflects the new truth.

### `FakeLoginItemService`

- Stored `var status: LoginItemStatus` initialised to `.disabled`.
- `setEnabled(true)` → sets `status = .enabled`, returns.
- `setEnabled(false)` → sets `status = .disabled`, returns.
- `setEnabled(_:)` accepts an optional injected `Error` factory (default `nil`) so a test can force the next call to throw `.underlying("test")`. After a forced throw, `status` is **not** mutated, matching the live behaviour.

### Why a protocol, not a static helper

- `CaffeineApp` is `@MainActor` and `@Observable`; tests cannot easily construct or replace static state.
- `LoginItemServiceTests` injects a `FakeLoginItemService` and asserts on `status` after `setEnabled`.
- A future "open System Settings" fallback path can implement the same protocol without touching the call site.

## `SettingsModel` Changes

```swift
@MainActor
@Observable
final class SettingsModel {
    var defaultDuration: Int
    var activateAtLaunch: Bool
    var deactivateOnManualSleep: Bool
    var keepAppsActive: Bool
    var startAtLogin: Bool            // NEW

    @ObservationIgnored
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.defaultDuration = defaults.integer(forKey: PreferenceKeys.defaultDuration)
        self.activateAtLaunch = defaults.bool(forKey: PreferenceKeys.activateAtLaunch)
        self.deactivateOnManualSleep = defaults.bool(forKey: PreferenceKeys.deactivateOnManualSleep)
        self.keepAppsActive = defaults.bool(forKey: PreferenceKeys.keepAppsActive)
        self.startAtLogin = defaults.bool(forKey: PreferenceKeys.startAtLogin)   // NEW
    }

    func persist(_ key: String) {
        let value: Any
        switch key {
        case PreferenceKeys.defaultDuration:        value = self.defaultDuration
        case PreferenceKeys.activateAtLaunch:        value = self.activateAtLaunch
        case PreferenceKeys.deactivateOnManualSleep: value = self.deactivateOnManualSleep
        case PreferenceKeys.keepAppsActive:          value = self.keepAppsActive
        case PreferenceKeys.startAtLogin:            value = self.startAtLogin   // NEW
        default:
            DZLog("SettingsModel.persist: unknown key \(key)")
            return
        }
        self.defaults.set(value, forKey: key)
    }
}

enum PreferenceKeys {
    static let activateAtLaunch        = "CAActivateAtLaunch"
    static let defaultDuration         = "CADefaultDuration"
    static let deactivateOnManualSleep = "CADeactivateOnManualSleep"
    static let keepAppsActive          = "CAKeepAppsActive"
    static let startAtLogin            = "CAStartAtLogin"   // NEW
}
```

`defaults.bool(forKey:)` returns `false` for missing keys, which matches the **default-off** goal with no extra branch.

## `GeneralSettingsView` Changes

Add a new `Section` after the "Activate when starting Caffeine" section:

```swift
Section {
    Toggle(
        String(localized: "Start at login"),
        isOn: Binding(
            get: { self.settings.startAtLogin },
            set: { newValue in
                self.settings.startAtLogin = newValue
                self.settings.persist(PreferenceKeys.startAtLogin)
                Task { await self.applyLoginItemChange(newValue) }
            }
        )
    )

    if let message = self.loginItemErrorMessage {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
    }

    Text(String(
        localized: "Automatically start Caffeine when you log in to your Mac.",
        comment: "Help text for the Start at login toggle"
    ))
    .font(.caption)
    .foregroundStyle(.secondary)
}
```

`applyLoginItemChange(_:)` and `loginItemErrorMessage` live as `@State` on the view:

```swift
@State private var loginItemErrorMessage: String?
@State private var loginItem: any LoginItemService = LoginItemService.live()

private func applyLoginItemChange(_ newValue: Bool) async {
    do {
        try await self.loginItem.setEnabled(newValue)
        self.loginItemErrorMessage = nil
    } catch {
        // Revert toggle + persisted preference.
        self.settings.startAtLogin.toggle()
        self.settings.persist(PreferenceKeys.startAtLogin)
        self.loginItemErrorMessage = error.localizedDescription
    }
}
```

`GeneralSettingsView` receives the same `LoginItemService` instance from `CaffeineApp` via a constructor parameter (default `.live()` for `#Preview`).

The init signature becomes:

```swift
init(
    viewModel: CaffeineViewModel,
    settings: SettingsModel,
    loginItem: any LoginItemService = LoginItemService.live()
)
```

## `CaffeineApp` Changes

```swift
@main
struct CaffeineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var viewModel = CaffeineViewModel()
    @State private var settings = SettingsModel()
    @State private var updater = UpdaterController()
    @State private var loginItem: any LoginItemService = .live()

    var body: some Scene {
        MenuBarExtra { /* unchanged */ } label: { /* unchanged */ }
            .menuBarExtraStyle(.menu)

        Settings {
            TabView {
                Tab(String(localized: "General"),  systemImage: "gearshape") {
                    GeneralSettingsView(
                        viewModel: self.viewModel,
                        settings: self.settings,
                        loginItem: self.loginItem
                    )
                }
                Tab(String(localized: "About"), systemImage: "info.circle") {
                    AboutSettingsView(updater: self.updater)
                }
            }
            .frame(minWidth: 440, minHeight: 360)
        }
        .defaultSize(width: 440, height: 360)
        .task {
            await self.loginItem.refresh()
        }
    }
}
```

The `.task` on `Settings` runs once when the Settings window is first constructed. We do **not** overwrite `settings.startAtLogin` with the system truth at launch — the user's explicit in-app choice is authoritative. The `status` is still useful for diagnostic logging (`DZLog`) if needed in the future.

## Error Handling

| Scenario | Behaviour |
|---|---|
| `register()` succeeds | `status = .enabled`; toggle stays on; no message. |
| `register()` throws (e.g. user denied authorisation) | Toggle reverted to off, `CAStartAtLogin = false`, red one-line message under the toggle using the `LoginItemError` description. |
| `unregister()` succeeds | `status = .disabled`; toggle stays off; no message. |
| `unregister()` throws | Toggle reverted to on, `CAStartAtLogin = true`, red one-line message under the toggle. |
| User manually changes Login Item in System Settings | Reflected on next launch via `refresh()` (status only; in-app preference is **not** auto-overwritten). |

## Localisation

Add two keys to every `Localizable.strings` in `src/Caffeine/Resources/<lang>.lproj/`:

| Key | English source string | Notes |
|---|---|---|
| `"Start at login"` | `Start at login` | Toggle label. |
| (toggle help) | `Automatically start Caffeine when you log in to your Mac.` | Secondary text under toggle. |

The English file is the source of truth; the other 13 languages (zh-Hans, de, ja, ko, es, fr, it, nl, pt, pt-BR, ru, uk) are filled in with a first-pass translation following the formality rules in `~/Agents/Guides/localization-guide.md`. This matches the pattern used in v1.3.0 ("Japanese localization, plus localizations with dynamic layout support").

The error message returned by `LoginItemError.errorDescription` is **not** localised through `Localizable.strings`; it is the fixed English string `"Couldn't change login item setting."` This is consistent with how the rest of the codebase surfaces error descriptions (e.g. `CaffeineViewModel.formattedTimeRemaining` returns inline `String(localized:)` strings directly). If localisation of error messages becomes a project-wide goal, that is a follow-up refactor.

## CHANGELOG Entry (to be appended under `## [Unreleased]`)

```markdown
### Added

- "Start at login" preference in Settings → General. When enabled,
  Caffeine registers itself with `SMAppService.mainApp` so it
  launches automatically on user login. Default is off.
```

## Testing

`LoginItemServiceTests.swift` (new file) covers:

1. `setEnabled(true)` flips `status` to `.enabled` and does not throw.
2. `setEnabled(false)` flips `status` to `.disabled` and does not throw.
3. `setEnabled(true)` with a forced-throw factory rethrows `LoginItemError.underlying` and leaves `status` unchanged.
4. `setEnabled(false)` with a forced-throw factory rethrows `LoginItemError.underlying` and leaves `status` unchanged.
5. `setEnabled(true)` followed by `refresh()` keeps `status = .enabled`.
6. `errorDescription` of `.underlying` and `.userCancelled` is non-nil.

If no XCTest target exists in the `.xcodeproj` today, this file is created in `src/Caffeine/Classes/Services/` and the implementation plan flags it as a **follow-up** — adding a test target requires editing `.xcodeproj`, which is forbidden by `AGENTS.md` without explicit user permission. The implementation code itself is fully testable once a target exists.

## Risks

1. **`SMAppService` API surface.** Exact method names (`register()` vs `enableLaunchAtLogin()`) and signature (`async throws` vs completion handler) vary across macOS SDKs. The implementation plan must `xcodebuild` the code and adjust against the actual SDK. The protocol shape (`setEnabled` / `refresh`) is the spec-level contract; the internal call is allowed to adapt.
2. **Sandbox interplay.** `SMAppService.mainApp` works inside a sandboxed app without additional entitlements. The plan should still verify by running once with the toggle on, then logging out and back in.
3. **Default-off and 1.6.x users.** No migration needed — `CAStartAtLogin` simply isn't set, `defaults.bool(forKey:)` returns `false`, behaviour unchanged.
4. **Forced-throw in tests.** `FakeLoginItemService`'s injected error factory is one-shot (it clears after firing) to mirror real service behaviour where a failed `register()` does not retroactively mutate state.

## Verification Plan

1. `xcodebuild -scheme "Caffeine" -destination "platform=macOS" build` succeeds.
2. `swiftformat .` reports no diff.
3. Manual launch:
   - Open Settings → General. The new "Start at login" toggle exists, defaults to off.
   - Toggle on. macOS shows the standard authorisation prompt for Login Items.
   - After approving, open System Settings → General → Login Items; "Caffeine" appears.
   - Toggle off in our app; "Caffeine" disappears from System Settings.
   - Deny the authorisation prompt; the toggle reverts to off and a red one-line message is shown.
   - Restart the Mac and confirm Caffeine launches silently and appears in the menu bar.
4. (If a test target exists) `xcodebuild -scheme "Caffeine" -destination "platform=macOS" test` succeeds.

## Out of Scope (Confirmed with User)

- Any change to the menu bar UI, the activation flow, `SleepPreventionManager`, or `ActivitySimulator`.
- Adding a new test target to `.xcodeproj` (would require editing the project file; flagged as a follow-up if no target exists).
- "Open at Login" deep-link into System Settings as a fallback for users who denied authorisation. The current design only shows a one-line message; a follow-up feature could offer a "Open Login Items Settings…" button.
