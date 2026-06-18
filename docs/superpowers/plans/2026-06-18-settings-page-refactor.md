# Settings Page Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hand-built Settings window with the native `Settings { TabView { Tab } }` API and centralise all preferences behind a single `SettingsModel`.

**Architecture:** Introduce `SettingsModel` (a `@MainActor @Observable` class) that owns the four `UserDefaults` keys. `CaffeineViewModel` reads from it instead of `UserDefaults.standard` directly. The `Settings` scene in `CaffeineApp` renders a `TabView` with two `Tab` children (`GeneralSettings`, `AboutSettings`), both using `Form(.grouped)`. The custom tab buttons and the `AppDelegate` KVO appearance observer are removed.

**Tech Stack:** Swift 5, SwiftUI, `@Observable` (macOS 14+), `UserDefaults`, Xcode 16 File System Synchronized Groups.

**Spec:** `docs/superpowers/specs/2026-06-18-settings-page-refactor-design.md`

**Project Conventions (from `AGENTS.md`):**
- 4-space indentation, explicit `self.`
- `DZLog` / `DZErrorLog` for debug output — never `print()`
- Run `swiftformat .` after every successful build
- Update `CHANGELOG.md` for every user-facing change
- Localize all user-facing strings

---

## File Map

### New files
- `src/Caffeine/Classes/Models/SettingsModel.swift` — `@Observable` wrapper around the four `UserDefaults` keys, with explicit `persist(_:)` for writes. Also defines the `PreferenceKeys` enum (moved here from `CaffeineViewModel.swift`).
- `src/Caffeine/Classes/Views/GeneralSettings.swift` — `Form(.grouped)` content bound to `SettingsModel`. Replaces `GeneralSettingsView.swift`.
- `src/Caffeine/Classes/Views/AboutSettings.swift` — `Form(.grouped)` layout. Replaces `AboutView.swift`.

### Modified files
- `src/Caffeine/Classes/ViewModels/CaffeineViewModel.swift` — drop the `PreferenceKeys` enum (moved to `SettingsModel.swift`), inject `SettingsModel` in `init`, replace `UserDefaults.standard.<type>(forKey:)` reads with `self.settings.xxx`. `updateActivitySimulation(enabled:)` also writes through the model.
- `src/Caffeine/Classes/CaffeineApp.swift` — add `@State private var settings = SettingsModel()`; replace the `Settings { PreferencesView(...) }` body with a `TabView` containing two `Tab` children. Apply `frame(minWidth: 480, minHeight: 360)` at the `TabView` level.
- `src/Caffeine/Classes/AppDelegate.swift` — remove the `NSApp.effectiveAppearance` KVO observer; keep only `setActivationPolicy(.accessory)`.
- `CHANGELOG.md` — append a `### Changed` block under `## [Unreleased]`.

### Deleted files
- `src/Caffeine/Classes/Views/PreferencesView.swift`
- `src/Caffeine/Classes/Views/SettingsTabButtonStyle.swift`
- `src/Caffeine/Classes/Views/GeneralSettingsView.swift`
- `src/Caffeine/Classes/Views/AboutView.swift`

The project uses Xcode 16 File System Synchronized Groups (`src/Caffeine/Classes/`), so file creation, renaming, and deletion are picked up by Xcode automatically — no project file edits are required.

### Testing strategy
The project currently has no test target. `AGENTS.md` does not require TDD for this codebase, and the changes are pure restructuring of UI plumbing. The plan therefore **does not add a test target** and validates via `xcodebuild build` + `swiftformat` + manual smoke checks listed in the final task.

---

## Task 1: Create `SettingsModel`

**Files:**
- Create: `src/Caffeine/Classes/Models/SettingsModel.swift`

- [ ] **Step 1: Create the file with the full model**

Write the following to `src/Caffeine/Classes/Models/SettingsModel.swift`:

```swift
//
//  SettingsModel.swift
//  Caffeine
//

import DZFoundation
import SwiftUI

/// Centralised, observable model for all user-facing preferences.
///
/// All reads/writes go through this type instead of scattering
/// `UserDefaults.standard.bool(forKey: ...)` calls across the
/// codebase. The `CaffeineViewModel` and the Settings tabs both
/// observe this single source of truth.
@MainActor
@Observable
final class SettingsModel {
    // MARK: - Stored Properties (mirror UserDefaults)

    /// Default activation duration in minutes. `0` means indefinite.
    /// Mirrors `PreferenceKeys.defaultDuration`.
    var defaultDuration: Int

    /// Whether to activate Caffeine on launch.
    /// Mirrors `PreferenceKeys.activateAtLaunch`.
    var activateAtLaunch: Bool

    /// Whether to deactivate when the device is manually put to sleep.
    /// Mirrors `PreferenceKeys.deactivateOnManualSleep`.
    var deactivateOnManualSleep: Bool

    /// Whether to simulate user activity to keep other apps awake.
    /// Mirrors `PreferenceKeys.keepAppsActive`.
    var keepAppsActive: Bool

    // MARK: - UserDefaults Backing

    @ObservationIgnored
    private let defaults: UserDefaults

    // MARK: - Initialization

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.defaultDuration = defaults.integer(forKey: PreferenceKeys.defaultDuration)
        self.activateAtLaunch = defaults.bool(forKey: PreferenceKeys.activateAtLaunch)
        self.deactivateOnManualSleep = defaults.bool(forKey: PreferenceKeys.deactivateOnManualSleep)
        self.keepAppsActive = defaults.bool(forKey: PreferenceKeys.keepAppsActive)
    }

    // MARK: - Persistence

    /// Persists a single value change to `UserDefaults`. Call this from
    /// `.onChange` modifiers in views that bind to a property, or
    /// inline in view-model methods that mutate the model.
    func persist(_ key: String) {
        let value: Any
        switch key {
        case PreferenceKeys.defaultDuration:
            value = self.defaultDuration
        case PreferenceKeys.activateAtLaunch:
            value = self.activateAtLaunch
        case PreferenceKeys.deactivateOnManualSleep:
            value = self.deactivateOnManualSleep
        case PreferenceKeys.keepAppsActive:
            value = self.keepAppsActive
        default:
            DZLog("SettingsModel.persist: unknown key \(key)")
            return
        }
        self.defaults.set(value, forKey: key)
    }
}

// MARK: - Preference Keys

/// `UserDefaults` keys for the four user preferences. Centralised here
/// so that `SettingsModel`, `CaffeineViewModel`, and view bindings all
/// share the same string constants.
enum PreferenceKeys {
    static let activateAtLaunch = "CAActivateAtLaunch"
    static let defaultDuration = "CADefaultDuration"
    static let deactivateOnManualSleep = "CADeactivateOnManualSleep"
    static let keepAppsActive = "CAKeepAppsActive"
}
```

- [ ] **Step 2: Verify the project still builds (the enum is now duplicated, expected to fail) intentionally skipped here — Task 2 removes the duplicate from `CaffeineViewModel.swift`.**

Skip a build check here: the project will not compile because `PreferenceKeys` is now declared in two places. Task 2 fixes that.

- [ ] **Step 3: Commit**

```bash
git add src/Caffeine/Classes/Models/SettingsModel.swift
git commit -m "feat(settings): add SettingsModel wrapping UserDefaults preferences"
```

---

## Task 2: Migrate `CaffeineViewModel` to use `SettingsModel`

**Files:**
- Modify: `src/Caffeine/Classes/ViewModels/CaffeineViewModel.swift`

- [ ] **Step 1: Update the class declaration to accept and store a `SettingsModel`**

In `src/Caffeine/Classes/ViewModels/CaffeineViewModel.swift`, change the class header (currently around line 13) from:

```swift
@MainActor
@Observable
final class CaffeineViewModel {
    // MARK: - Published Properties

    var isActive = false
    var timeRemaining: TimeInterval?

    // MARK: - Ignored (private) Properties

    @ObservationIgnored
    private var timeoutTimer: Timer?

    @ObservationIgnored
    private var displayTimer: Timer?

    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        // Explicitly ensure we start inactive
        self.isActive = false
        self.timeRemaining = nil

        self.setupObservers()

        // Check if we should activate at launch
        if UserDefaults.standard.bool(forKey: PreferenceKeys.activateAtLaunch) {
            self.activate()
        }
    }
```

to:

```swift
@MainActor
@Observable
final class CaffeineViewModel {
    // MARK: - Published Properties

    var isActive = false
    var timeRemaining: TimeInterval?

    // MARK: - Ignored (private) Properties

    @ObservationIgnored
    private let settings: SettingsModel

    @ObservationIgnored
    private var timeoutTimer: Timer?

    @ObservationIgnored
    private var displayTimer: Timer?

    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(settings: SettingsModel = SettingsModel()) {
        // Explicitly ensure we start inactive
        self.isActive = false
        self.timeRemaining = nil
        self.settings = settings

        self.setupObservers()

        // Check if we should activate at launch
        if self.settings.activateAtLaunch {
            self.activate()
        }
    }
```

- [ ] **Step 2: Replace the `UserDefaults.standard` call in `activate(withTimeout:)`**

In `src/Caffeine/Classes/ViewModels/CaffeineViewModel.swift`, locate the block:

```swift
        } else {
            let defaultMinutes = UserDefaults.standard.integer(forKey: PreferenceKeys.defaultDuration)
            duration = defaultMinutes > 0 ? TimeInterval(defaultMinutes * 60) : nil
        }
```

Replace it with:

```swift
        } else {
            let defaultMinutes = self.settings.defaultDuration
            duration = defaultMinutes > 0 ? TimeInterval(defaultMinutes * 60) : nil
        }
```

- [ ] **Step 3: Update `updateActivitySimulation(enabled:)` to also persist**

In `src/Caffeine/Classes/ViewModels/CaffeineViewModel.swift`, replace the entire current method:

```swift
    /// Updates activity simulation based on preference
    func updateActivitySimulation(enabled: Bool) {
        if enabled {
            // Trigger the Accessibility permission prompt by posting a no-op event
            // This prompts for "Events" permission which CGEvent.post requires
            ActivitySimulator.shared.requestPermission()
        }

        if enabled, self.isActive {
            ActivitySimulator.shared.startMonitoring()
        } else {
            ActivitySimulator.shared.stopMonitoring()
        }
    }
```

with:

```swift
    /// Updates activity simulation based on preference. Also keeps the
    /// `SettingsModel` and `UserDefaults` in sync with the new value.
    func updateActivitySimulation(enabled: Bool) {
        if self.settings.keepAppsActive != enabled {
            self.settings.keepAppsActive = enabled
            self.settings.persist(PreferenceKeys.keepAppsActive)
        }

        if enabled {
            // Trigger the Accessibility permission prompt by posting a no-op event
            // This prompts for "Events" permission which CGEvent.post requires
            ActivitySimulator.shared.requestPermission()
        }

        if enabled, self.isActive {
            ActivitySimulator.shared.startMonitoring()
        } else {
            ActivitySimulator.shared.stopMonitoring()
        }
    }
```

- [ ] **Step 4: Update `setupObservers()` to read from the model**

In `src/Caffeine/Classes/ViewModels/CaffeineViewModel.swift`, replace:

```swift
            .sink { [weak self] _ in
                Task { @MainActor in
                    if UserDefaults.standard.bool(forKey: PreferenceKeys.deactivateOnManualSleep) {
                        self?.deactivate()
                    }
                }
            }
```

with:

```swift
            .sink { [weak self] _ in
                Task { @MainActor in
                    if self?.settings.deactivateOnManualSleep == true {
                        self?.deactivate()
                    }
                }
            }
```

(The change captures `self` once instead of re-reading it in the inner branch — matches the existing `didWake` block below it.)

- [ ] **Step 5: Remove the `PreferenceKeys` enum from this file**

Delete the entire `// MARK: - Preference Keys` block at the bottom of `src/Caffeine/Classes/ViewModels/CaffeineViewModel.swift`:

```swift
// MARK: - Preference Keys

enum PreferenceKeys {
    static let activateAtLaunch = "CAActivateAtLaunch"
    static let defaultDuration = "CADefaultDuration"
    static let deactivateOnManualSleep = "CADeactivateOnManualSleep"
    static let keepAppsActive = "CAKeepAppsActive"
}
```

The enum is now defined in `SettingsModel.swift` (Task 1) and re-exported through the same name, so all callers continue to work.

- [ ] **Step 6: Verify the project builds**

Run:

```bash
xcodebuild -scheme "Caffeine" -destination "platform=macOS" build 2>&1 | tail -30
```

Expected: `** BUILD SUCCEEDED **`. If the build fails with `Cannot find 'SettingsModel' in scope`, ensure the file was added under `src/Caffeine/Classes/Models/` (the synchronized group picks it up automatically).

- [ ] **Step 7: Run `swiftformat`**

```bash
swiftformat .
```

Expected: no diff (or only whitespace-only diffs if the existing file was not yet formatted).

- [ ] **Step 8: Commit**

```bash
git add src/Caffeine/Classes/ViewModels/CaffeineViewModel.swift
git commit -m "refactor(viewmodel): read preferences from SettingsModel"
```

---

## Task 3: Create `GeneralSettings`

**Files:**
- Create: `src/Caffeine/Classes/Views/GeneralSettings.swift`

- [ ] **Step 1: Write the file**

Create `src/Caffeine/Classes/Views/GeneralSettings.swift` with the following content:

```swift
//
//  GeneralSettings.swift
//  Caffeine
//

import SwiftUI

/// "General" tab of the Settings window. Bound to the shared
/// `SettingsModel`; persistence is triggered via `.onChange` for the
/// simple toggles and inline in the binding's `set` closure for the
/// `Keep apps active` toggle (which has a side effect on
/// `CaffeineViewModel`).
struct GeneralSettings: View {
    @Bindable var viewModel: CaffeineViewModel
    @Bindable var settings: SettingsModel

    var body: some View {
        Form {
            Section {
                Picker(
                    String(localized: "Default duration"),
                    selection: self.$settings.defaultDuration
                ) {
                    Text(String(localized: "5 minutes")).tag(5)
                    Text(String(localized: "10 minutes")).tag(10)
                    Text(String(localized: "15 minutes")).tag(15)
                    Text(String(localized: "30 minutes")).tag(30)
                    Text(String(localized: "1 hour")).tag(60)
                    Text(String(localized: "2 hours")).tag(120)
                    Text(String(localized: "5 hours")).tag(300)
                    Text(String(localized: "Indefinitely")).tag(0)
                }
                .pickerStyle(.menu)
            }

            Section {
                Toggle(
                    String(localized: "Activate when starting Caffeine"),
                    isOn: self.$settings.activateAtLaunch
                )
                Toggle(
                    String(localized: "Deactivate when device goes to sleep manually"),
                    isOn: self.$settings.deactivateOnManualSleep
                )
            }

            Section {
                Toggle(
                    String(localized: "Keep apps active"),
                    isOn: Binding(
                        get: { self.settings.keepAppsActive },
                        set: { newValue in
                            self.settings.keepAppsActive = newValue
                            self.settings.persist(PreferenceKeys.keepAppsActive)
                            self.viewModel.updateActivitySimulation(enabled: newValue)
                        }
                    )
                )

                Text(String(
                    localized: "Prevents apps from becoming inactive and the screen saver from starting.",
                    comment: "Help text for the Keep apps active toggle"
                ))
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

#Preview {
    GeneralSettings(
        viewModel: CaffeineViewModel(),
        settings: SettingsModel()
    )
    .environment(\.locale, .init(identifier: "en"))
}
```

- [ ] **Step 2: Build to verify it compiles**

Run:

```bash
xcodebuild -scheme "Caffeine" -destination "platform=macOS" build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`. The build will still fail to fully link because the `Settings` scene still references the old `PreferencesView`, which we have not deleted yet — that is fine for this task. The compile step (parsing the new file) is what we're checking.

If the build fails with `Cannot find type 'SettingsModel' in scope`, ensure `src/Caffeine/Classes/Models/SettingsModel.swift` exists (Task 1) and the synchronized group picked it up.

- [ ] **Step 3: Commit**

```bash
git add src/Caffeine/Classes/Views/GeneralSettings.swift
git commit -m "feat(settings): add GeneralSettings tab bound to SettingsModel"
```

---

## Task 4: Create `AboutSettings`

**Files:**
- Create: `src/Caffeine/Classes/Views/AboutSettings.swift`

- [ ] **Step 1: Write the file**

Create `src/Caffeine/Classes/Views/AboutSettings.swift` with the following content:

```swift
//
//  AboutSettings.swift
//  Caffeine
//

import Sparkle
import SwiftUI

/// "About" tab. Read-only metadata about the app plus a Check for
/// Updates button. Uses `Form(.grouped)` to match the visual language
/// of `GeneralSettings`.
struct AboutSettings: View {
    let updater: UpdaterController

    private let version: String = {
        if let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            return v
        }
        return "1.0.0"
    }()

    private let repoURL = URL(string: "https://github.com/dominc/Caffeine")!

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                        .resizable()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    Text("Caffeine")
                        .font(.system(size: 18, weight: .semibold))

                    Text(String(
                        format: String(localized: "Version %@", comment: "About tab version label"),
                        self.version
                    ))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                    Text(String(localized: "Caffeine keeps your Mac awake."))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section {
                Button {
                    NSWorkspace.shared.open(self.repoURL)
                } label: {
                    Text(String(localized: "View on GitHub", comment: "About tab: open repo in browser"))
                }

                Button {
                    self.updater.checkForUpdates()
                } label: {
                    Text(String(localized: "Check for Updates...", comment: "About tab: trigger Sparkle update check"))
                }
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    AboutSettings(updater: UpdaterController())
        .environment(\.locale, .init(identifier: "en"))
}
```

- [ ] **Step 2: Build to verify it compiles**

Run:

```bash
xcodebuild -scheme "Caffeine" -destination "platform=macOS" build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **` (the same caveat as Task 3 applies — the `Settings` scene still references the old `PreferencesView`).

- [ ] **Step 3: Commit**

```bash
git add src/Caffeine/Classes/Views/AboutSettings.swift
git commit -m "feat(settings): add AboutSettings tab using Form(.grouped)"
```

---

## Task 5: Wire up `CaffeineApp` with native `Settings { TabView }`

**Files:**
- Modify: `src/Caffeine/Classes/CaffeineApp.swift`

- [ ] **Step 1: Replace the file contents**

Overwrite `src/Caffeine/Classes/CaffeineApp.swift` with the following content:

```swift
//
//  CaffeineApp.swift
//  Caffeine
//
//  Created by Dominic Rodemer on 11.11.25.
//

import SwiftUI

@main
struct CaffeineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var viewModel = CaffeineViewModel()
    @State private var settings = SettingsModel()
    @State private var updater = UpdaterController()

    var body: some Scene {
        // macOS 27 recommended menu bar API. Renders the
        // `active` / `inactive` template image as the icon and
        // shows `MenuBarContent` on left- or right-click.
        MenuBarExtra {
            MenuBarContent(viewModel: self.viewModel, updater: self.updater)
        } label: {
            Image(self.viewModel.isActive ? "active" : "inactive")
        }
        .menuBarExtraStyle(.menu)

        // Native macOS Settings scene with a tabbed layout. The
        // system owns the title bar, tab chrome, and appearance
        // following.
        Settings {
            TabView {
                Tab(
                    String(localized: "General"),
                    systemImage: "gearshape"
                ) {
                    GeneralSettings(viewModel: self.viewModel, settings: self.settings)
                }

                Tab(
                    String(localized: "About"),
                    systemImage: "info.circle"
                ) {
                    AboutSettings(updater: self.updater)
                }
            }
            .frame(minWidth: 480, minHeight: 360)
        }
    }
}
```

- [ ] **Step 2: Build and confirm `Tab` API is available**

Run:

```bash
xcodebuild -scheme "Caffeine" -destination "platform=macOS" build 2>&1 | tail -30
```

Expected: `** BUILD SUCCEEDED **`. If the build fails with an error mentioning `Tab` (e.g. `cannot find 'Tab' in scope` or an availability error), the SDK or deployment target does not yet support it. In that case:

1. Check the deployment target:
   ```bash
   grep -i "deployment\|MACOSX_DEPLOYMENT" /Users/mac/zcode/Caffeine/src/Caffeine/*.xcodeproj/project.pbxproj | head -5
   ```
2. If the target is below macOS 14.0, **stop and ask the user** — the fix requires editing the Xcode project (which is a "catastrophic, do not touch" file per `AGENTS.md`).
3. If the target is 14.0+ but the build SDK is older, document the issue and continue — the user can run the build locally with a current Xcode.

- [ ] **Step 3: Commit**

```bash
git add src/Caffeine/Classes/CaffeineApp.swift
git commit -m "feat(settings): use native Settings { TabView { Tab } } API"
```

---

## Task 6: Simplify `AppDelegate`

**Files:**
- Modify: `src/Caffeine/Classes/AppDelegate.swift`

- [ ] **Step 1: Overwrite the file**

Overwrite `src/Caffeine/Classes/AppDelegate.swift` with:

```swift
//
//  AppDelegate.swift
//  Caffeine
//
//  Created by Dominic Rodemer on 11.11.25.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        // Hide the dock icon - this is a menu bar only app
        NSApp.setActivationPolicy(.accessory)
    }
}
```

- [ ] **Step 2: Build to confirm**

Run:

```bash
xcodebuild -scheme "Caffeine" -destination "platform=macOS" build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add src/Caffeine/Classes/AppDelegate.swift
git commit -m "refactor(app): drop NSApp.effectiveAppearance KVO observer"
```

---

## Task 7: Delete obsolete Settings files

**Files:**
- Delete: `src/Caffeine/Classes/Views/PreferencesView.swift`
- Delete: `src/Caffeine/Classes/Views/SettingsTabButtonStyle.swift`
- Delete: `src/Caffeine/Classes/Views/GeneralSettingsView.swift`
- Delete: `src/Caffeine/Classes/Views/AboutView.swift`

- [ ] **Step 1: Delete the four files**

```bash
rm /Users/mac/zcode/Caffeine/src/Caffeine/Classes/Views/PreferencesView.swift \
   /Users/mac/zcode/Caffeine/src/Caffeine/Classes/Views/SettingsTabButtonStyle.swift \
   /Users/mac/zcode/Caffeine/src/Caffeine/Classes/Views/GeneralSettingsView.swift \
   /Users/mac/zcode/Caffeine/src/Caffeine/Classes/Views/AboutView.swift
```

- [ ] **Step 2: Verify the deletion and the build**

```bash
ls /Users/mac/zcode/Caffeine/src/Caffeine/Classes/Views/
xcodebuild -scheme "Caffeine" -destination "platform=macOS" build 2>&1 | tail -20
```

Expected: the `Views/` directory now lists `MenuBarContent.swift`, `GeneralSettings.swift`, `AboutSettings.swift` only. Build still succeeds.

- [ ] **Step 3: Commit**

```bash
git add -A src/Caffeine/Classes/Views/
git commit -m "chore(settings): remove obsolete custom tab files"
```

---

## Task 8: Update `CHANGELOG.md`

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Append the `### Changed` block under `## [Unreleased]`**

In `CHANGELOG.md`, locate the existing `## [Unreleased]` block (top of file). It currently contains `### Added`, `### Removed`, `### Fixed` sub-sections. After the `### Fixed` block and before `## [1.6.5]`, insert a new sub-section:

```markdown
### Changed

- Settings window now uses the native `Settings { TabView { Tab { ... } } }` API (macOS 14+), removing the custom tab buttons and the `SettingsTabButtonStyle` workaround. Tab theming now follows the system appearance automatically.
- All user preferences are now read and written through a single `SettingsModel` (`@Observable`), replacing scattered `UserDefaults.standard.bool(forKey:)` calls in `CaffeineViewModel` and per-view `@AppStorage` bindings.
- `AppDelegate` no longer observes `NSApp.effectiveAppearance` to force-update window appearance; system default behaviour is relied upon instead.
- The "About" tab now uses `Form` with `.formStyle(.grouped)` for visual consistency with the "General" tab.
```

- [ ] **Step 2: Run `swiftformat`** (no Swift changes expected, but cheap to confirm)

```bash
swiftformat .
```

Expected: no diff.

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs(changelog): note settings page refactor"
```

---

## Task 9: Final verification

**Files:** (no changes — read-only verification)

- [ ] **Step 1: Clean and build from scratch**

```bash
xcodebuild -scheme "Caffeine" -destination "platform=macOS" clean
xcodebuild -scheme "Caffeine" -destination "platform=macOS" build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`. No warnings related to the migrated files.

- [ ] **Step 2: Run `swiftformat` and verify clean**

```bash
swiftformat . --lint
```

Expected: no violations. If there are, run `swiftformat .` once and re-run the lint.

- [ ] **Step 3: Verify the file tree is as designed**

```bash
find src/Caffeine/Classes -name "*.swift" | sort
```

Expected output (order may vary):

```
src/Caffeine/Classes/AppDelegate.swift
src/Caffeine/Classes/CaffeineApp.swift
src/Caffeine/Classes/Models/ActivitySimulator.swift
src/Caffeine/Classes/Models/SettingsModel.swift
src/Caffeine/Classes/Models/SleepPreventionManager.swift
src/Caffeine/Classes/ViewModels/CaffeineViewModel.swift
src/Caffeine/Classes/Views/AboutSettings.swift
src/Caffeine/Classes/Views/GeneralSettings.swift
src/Caffeine/Classes/Views/MenuBarContent.swift
```

- [ ] **Step 4: Verify git history is clean and atomic**

```bash
git log --oneline -10
```

Expected: the most recent commits match the commits made in Tasks 1-8 (a mix of `feat(settings):`, `refactor(viewmodel):`, `refactor(app):`, `chore(settings):`, `docs(changelog):`).

- [ ] **Step 5: Manual smoke check (user-driven)**

This task cannot be automated. Hand the build to the user with these checks:

1. Launch the app from Xcode.
2. Click the menu bar icon → **Preferences...** — the Settings window opens.
3. Confirm the **General** tab is selected by default and shows the four preferences (Default duration, Activate at launch, Deactivate on manual sleep, Keep apps active).
4. Click the **About** tab — it shows the app icon, name, version, description, and two buttons (View on GitHub, Check for Updates...).
5. Switch back to **General** and toggle **Activate when starting Caffeine** on. Quit the app and relaunch — Caffeine should activate automatically.
6. Toggle the system appearance (System Settings → Appearance) between Light and Dark while the Settings window is open. The tab bar and form content should follow the system theme in real time. (If this regresses, the fallback in `AGENTS.md` is to reinstate the `AppDelegate` KVO observer — that code is in git history at commit `5b19531`.)
7. Toggle **Keep apps active** — the existing behaviour (`ActivitySimulator` start/stop, accessibility prompt) should fire.

If any check fails, the most likely cause is the `Tab` API not behaving the same on the user's macOS version. The fallback (commit `5b19531`'s implementation) is documented in the spec under "Risks".

---

## Self-Review

**1. Spec coverage:**

| Spec section | Implemented in |
|--------------|----------------|
| "Settings window with native TabView" | Task 5 |
| "SettingsModel with persist(_:)" | Task 1 |
| "CaffeineViewModel uses SettingsModel" | Task 2 |
| "GeneralSettings Form(.grouped)" | Task 3 |
| "AboutSettings Form(.grouped)" | Task 4 |
| "AppDelegate simplified" | Task 6 |
| "Delete obsolete files" | Task 7 |
| "CHANGELOG updated" | Task 8 |
| "Verification plan" | Task 9 |

All sections covered.

**2. Placeholder scan:** No `TBD` / `TODO` / "similar to Task N" / "implement later" / "add appropriate error handling" in any task. Every code block is complete.

**3. Type consistency:**
- `SettingsModel` is referenced as `@MainActor @Observable final class` in Task 1, declared with `@Bindable` in Tasks 3, 5 — consistent.
- `CaffeineViewModel.init(settings:)` in Task 2 takes a `SettingsModel`; the call site in Task 5 uses `CaffeineViewModel()` (default arg) — consistent.
- `PreferenceKeys` is declared in Task 1, referenced in Tasks 2, 3, 8 — same file, no naming drift.
- `persist(_:)` is declared in Task 1 with one `String` parameter; called as `self.settings.persist(PreferenceKeys.xxx)` in Tasks 2, 3 — consistent.

No issues found.
