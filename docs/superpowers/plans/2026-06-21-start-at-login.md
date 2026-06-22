# Start at Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Start at login" toggle in the General settings tab that registers Caffeine with `SMAppService.mainApp` when enabled and unregisters it when disabled. Failures surface as a one-line red message under the toggle.

**Architecture:** A new `LoginItemService` protocol (with `LiveLoginItemService` and `FakeLoginItemService` implementations) wraps `SMAppService.mainApp` so the call site is testable. `SettingsModel` gains a `startAtLogin: Bool` field persisted via `UserDefaults` under `CAStartAtLogin`. `GeneralSettingsView` binds a new toggle section, calls `LoginItemService.setEnabled(_:)` on change, and reverts the toggle + shows an error message on failure. `CaffeineApp` instantiates the live service and triggers a one-time `refresh()` when the Settings scene first appears.

**Tech Stack:** Swift 5, SwiftUI, `@Observable` (macOS 14+), `ServiceManagement` (`SMAppService`), `UserDefaults`, Xcode 16 File System Synchronized Groups.

**Spec:** `docs/superpowers/specs/2026-06-21-start-at-login-design.md`

**Project Conventions (from `AGENTS.md`):**
- 4-space indentation, explicit `self.`
- `DZLog` / `DZErrorLog` for debug output — never `print()`
- Run `swiftformat .` after every successful build
- Update `CHANGELOG.md` for every user-facing change
- Localize all user-facing strings

**Special notes for this plan:**
- `SMAppService` is available on macOS 13+. The project deployment target is macOS 13.5, so the live implementation is gated to `if #available(macOS 13.0, *)` only at the **call site**, not the protocol. The protocol is unconditional.
- No test target currently exists in the project (confirmed: `find src -name '*Test*' -o -name '*Tests*'` returns nothing). Per `AGENTS.md`, adding a test target requires editing `.xcodeproj`, which is forbidden. The plan therefore **creates the test file in the source tree as a documented follow-up** so the implementation code stays testable once a target exists.

---

## File Map

### New files
- `src/Caffeine/Classes/Services/LoginItemService.swift` — `protocol LoginItemService`, `enum LoginItemStatus`, `enum LoginItemError`, `LiveLoginItemService`, `FakeLoginItemService`.
- `src/Caffeine/Classes/Services/LoginItemServiceTests.swift` — XCTest cases for `FakeLoginItemService`. Will be added to a test target once one exists (follow-up).

### Modified files
- `src/Caffeine/Classes/Models/SettingsModel.swift` — add `var startAtLogin: Bool`; add `PreferenceKeys.startAtLogin = "CAStartAtLogin"`; handle it in `init` and `persist(_:)`.
- `src/Caffeine/Classes/Views/GeneralSettingsView.swift` — add a new `Section` with the toggle, optional red error message, and secondary help caption. Receive a `LoginItemService` parameter.
- `src/Caffeine/Classes/CaffeineApp.swift` — add `@State private var loginItem: any LoginItemService = .live()`; pass it into `GeneralSettingsView`; add `.task` to trigger `refresh()` once.
- `CHANGELOG.md` — append an `### Added` block under `## [Unreleased]`.
- `src/Caffeine/Resources/<lang>.lproj/Localizable.strings` (×14) — add two keys (`"Start at login"`, `"Automatically start Caffeine when you log in to your Mac."`).

### Deleted files
None.

The project uses Xcode 16 File System Synchronized Groups (`src/Caffeine/Classes/`), so adding files under `src/Caffeine/Classes/Services/` is picked up by Xcode automatically.

---

## Task 1: Create `LoginItemService` skeleton (protocol + enums + Fake)

**Files:**
- Create: `src/Caffeine/Classes/Services/LoginItemService.swift`

- [ ] **Step 1: Create the file with protocol, enums, and `FakeLoginItemService`**

Write the following to `src/Caffeine/Classes/Services/LoginItemService.swift`:

```swift
//
//  LoginItemService.swift
//  Caffeine
//

import Foundation

/// Real-system status of the Caffeine login item.
enum LoginItemStatus: Equatable {
    /// Caffeine is registered as a login item.
    case enabled
    /// Caffeine is not registered.
    case disabled
    /// A previous registration attempt was denied; the user must
    /// approve Caffeine in System Settings → General → Login Items
    /// before the app can register itself.
    case requiresApproval
    /// System reported a status that does not map to the cases above
    /// (e.g. an SDK newer than this build expected).
    case unknown
}

/// Errors thrown by `LoginItemService.setEnabled(_:)`.
enum LoginItemError: LocalizedError {
    case underlying(String)
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .underlying:
            "Couldn't change login item setting."
        case .userCancelled:
            "Login item change was cancelled."
        }
    }
}

/// Abstraction over the macOS login-item API so views never depend on
/// `SMAppService` directly. The live implementation is
/// `LiveLoginItemService`; the in-memory `FakeLoginItemService` is
/// used in tests (and as a placeholder until a test target exists).
@MainActor
protocol LoginItemService: AnyObject {
    /// Last known system status. Initial value is `.unknown` until
    /// `refresh()` completes at least once.
    var status: LoginItemStatus { get }

    /// Asks the system for the current login-item status and stores
    /// it in `status`. Safe to call multiple times.
    func refresh() async

    /// Requests that the system enable or disable Caffeine as a
    /// login item. On success, `status` reflects the new truth. On
    /// failure, throws `LoginItemError` and `status` is unchanged.
    func setEnabled(_ enabled: Bool) async throws
}

extension LoginItemService {
    /// Convenience factory for the live, system-backed implementation.
    static func live() -> any LoginItemService {
        LiveLoginItemService()
    }
}

/// In-memory `LoginItemService` for tests and for follow-up work that
/// needs a deterministic service without invoking `SMAppService`.
///
/// The optional `nextError` closure, when set, causes the next call
/// to `setEnabled(_:)` to throw the returned error and leaves `status`
/// unchanged. It is consumed (cleared) after one invocation, matching
/// the live behaviour where a failed register/unregister does not
/// retroactively mutate state.
@MainActor
final class FakeLoginItemService: LoginItemService {
    private(set) var status: LoginItemStatus = .disabled

    private var nextError: (@Sendable () -> LoginItemError)?

    init(initialStatus: LoginItemStatus = .disabled) {
        self.status = initialStatus
    }

    /// Inject a one-shot error to be thrown by the next
    /// `setEnabled(_:)` call. Pass `nil` to clear.
    func setNextError(_ factory: (@Sendable () -> LoginItemError)?) {
        self.nextError = factory
    }

    func refresh() async {
        // No-op: status already reflects the latest truth.
    }

    func setEnabled(_ enabled: Bool) async throws {
        if let factory = self.nextError {
            self.nextError = nil
            throw factory()
        }
        self.status = enabled ? .enabled : .disabled
    }
}
```

- [ ] **Step 2: Verify the project builds**

Run:

```bash
xcodebuild -scheme "Caffeine" -destination "platform=macOS" build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`. `LiveLoginItemService` is not defined yet, but since it is only referenced from a function body (`live()`), the linker does not need it yet — the compile step should still succeed.

If the build fails with `Cannot find type 'LiveLoginItemService' in scope`, that means the compiler is more eager than expected. Add a stub at the bottom of the file to silence it for now (the real implementation is added in Task 2):

```swift
import ServiceManagement

@MainActor
final class LiveLoginItemService: LoginItemService {
    private(set) var status: LoginItemStatus = .unknown

    func refresh() async {
        // Implemented in Task 2.
    }

    func setEnabled(_ enabled: Bool) async throws {
        // Implemented in Task 2.
    }
}
```

Then re-run the build.

- [ ] **Step 3: Run `swiftformat`**

```bash
swiftformat .
```

Expected: no diff.

- [ ] **Step 4: Commit**

```bash
git add src/Caffeine/Classes/Services/LoginItemService.swift
git commit -m "feat(login): add LoginItemService protocol and FakeLoginItemService"
```

---

## Task 2: Implement `LiveLoginItemService`

**Files:**
- Modify: `src/Caffeine/Classes/Services/LoginItemService.swift`

- [ ] **Step 1: Verify the `SMAppService` API surface available in this SDK**

Run:

```bash
xcodebuild -scheme "Caffeine" -destination "platform=macOS" -showBuildSettings 2>/dev/null | grep -E "MACOSX_DEPLOYMENT_TARGET|SDKROOT"
```

Note `MACOSX_DEPLOYMENT_TARGET`. Expected: `13.5` (matches `AGENTS.md`). `SMAppService` is available on macOS 13+, so no availability gate is needed beyond what the SDK already provides.

- [ ] **Step 2: Replace the `LiveLoginItemService` stub with the real implementation**

In `src/Caffeine/Classes/Services/LoginItemService.swift`, replace the existing stub block:

```swift
@MainActor
final class LiveLoginItemService: LoginItemService {
    private(set) var status: LoginItemStatus = .unknown

    func refresh() async {
        // Implemented in Task 2.
    }

    func setEnabled(_ enabled: Bool) async throws {
        // Implemented in Task 2.
    }
}
```

with:

```swift
/// Live `LoginItemService` backed by `SMAppService.mainApp`.
@MainActor
final class LiveLoginItemService: LoginItemService {
    private let service = SMAppService.mainApp

    private(set) var status: LoginItemStatus = .unknown

    func refresh() async {
        switch self.service.status {
        case .enabled:
            self.status = .enabled
        case .requiresApproval:
            self.status = .requiresApproval
        case .notRegistered, .notFound:
            self.status = .disabled
        @unknown default:
            self.status = .unknown
        }
    }

    func setEnabled(_ enabled: Bool) async throws {
        do {
            if enabled {
                try await self.service.register()
            } else {
                try await self.service.unregister()
            }
        } catch is CancellationError {
            throw LoginItemError.userCancelled
        } catch {
            DZErrorLog(error)
            throw LoginItemError.underlying(String(describing: error))
        }
        await self.refresh()
    }
}
```

Add the import at the top of the file (next to `import Foundation`):

```swift
import DZFoundation
import ServiceManagement
```

- [ ] **Step 3: Build to verify the live service compiles**

Run:

```bash
xcodebuild -scheme "Caffeine" -destination "platform=macOS" build 2>&1 | tail -30
```

Expected: `** BUILD SUCCEEDED **`. If the build fails because the SDK in use does not have `async` versions of `register()` / `unregister()`, fall back to the completion-handler variants:

```swift
func setEnabled(_ enabled: Bool) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        let handler: (Error?) -> Void = { error in
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: ())
            }
        }
        if enabled {
            self.service.register(handler: handler)
        } else {
            self.service.unregister(handler: handler)
        }
    }
    // Re-throw mapping happens below in the do/catch — this approach
    // already gives us a thrown Error.
}
```

If that fallback is used, also remove the `try await` from the body inside the `do` block in the original code and rely on the continuation throwing. The map-to-`LoginItemError` logic in the catch arm above continues to apply.

**Document the chosen API in the commit message body** (e.g. "uses async register/unregister from SMAppService").

- [ ] **Step 4: Run `swiftformat`**

```bash
swiftformat .
```

Expected: no diff.

- [ ] **Step 5: Commit**

```bash
git add src/Caffeine/Classes/Services/LoginItemService.swift
git commit -m "feat(login): implement LiveLoginItemService over SMAppService.mainApp"
```

---

## Task 3: Add `startAtLogin` to `SettingsModel`

**Files:**
- Modify: `src/Caffeine/Classes/Models/SettingsModel.swift`

- [ ] **Step 1: Add the property**

In `src/Caffeine/Classes/Models/SettingsModel.swift`, locate the four stored properties (around lines 22-34) and add `startAtLogin` after `keepAppsActive`:

```swift
    /// Whether to simulate user activity to keep other apps awake.
    /// Mirrors `PreferenceKeys.keepAppsActive`.
    var keepAppsActive: Bool

    /// Whether to register Caffeine as a login item so it launches
    /// at user login. Mirrors `PreferenceKeys.startAtLogin`.
    var startAtLogin: Bool
```

- [ ] **Step 2: Initialise it in `init`**

In `init(defaults:)`, after the existing four reads, add:

```swift
        self.startAtLogin = defaults.bool(forKey: PreferenceKeys.startAtLogin)
```

`defaults.bool(forKey:)` returns `false` for missing keys, which matches the **default-off** goal.

- [ ] **Step 3: Handle it in `persist(_:)`**

In the `switch` inside `func persist(_ key: String)`, add a new case before `default`:

```swift
        case PreferenceKeys.startAtLogin:
            value = self.startAtLogin
```

- [ ] **Step 4: Add the new key to `PreferenceKeys`**

At the bottom of `SettingsModel.swift`, in the `PreferenceKeys` enum, add:

```swift
    static let startAtLogin = "CAStartAtLogin"
```

- [ ] **Step 5: Build to verify**

Run:

```bash
xcodebuild -scheme "Caffeine" -destination "platform=macOS" build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Run `swiftformat`**

```bash
swiftformat .
```

Expected: no diff.

- [ ] **Step 7: Commit**

```bash
git add src/Caffeine/Classes/Models/SettingsModel.swift
git commit -m "feat(settings): add startAtLogin preference to SettingsModel"
```

---

## Task 4: Wire the toggle into `GeneralSettingsView`

**Files:**
- Modify: `src/Caffeine/Classes/Views/GeneralSettingsView.swift`

- [ ] **Step 1: Update the view struct**

Replace the entire `GeneralSettingsView` struct in `src/Caffeine/Classes/Views/GeneralSettingsView.swift` (currently lines 13-87) with:

```swift
//
//  GeneralSettingsView.swift
//  Caffeine
//

import SwiftUI

/// "General" tab of the Settings window. Bound to the shared
/// `SettingsModel`; persistence is triggered via `.onChange` for the
/// simple toggles and inline in the binding's `set` closure for the
/// `Keep apps active` toggle (which has a side effect on
/// `CaffeineViewModel`) and the `Start at login` toggle (which calls
/// `LoginItemService`).
struct GeneralSettingsView: View {
    @Bindable var viewModel: CaffeineViewModel
    @Bindable var settings: SettingsModel
    var loginItem: any LoginItemService = LoginItemService.live()

    @State private var loginItemErrorMessage: String?

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

    /// Apply the user's toggle change to the underlying
    /// `LoginItemService`. On failure, revert both the in-memory
    /// setting and the persisted preference, and surface a one-line
    /// error message under the toggle.
    private func applyLoginItemChange(_ newValue: Bool) async {
        do {
            try await self.loginItem.setEnabled(newValue)
            self.loginItemErrorMessage = nil
        } catch {
            self.settings.startAtLogin.toggle()
            self.settings.persist(PreferenceKeys.startAtLogin)
            self.loginItemErrorMessage = error.localizedDescription
        }
    }
}

#Preview {
    GeneralSettingsView(
        viewModel: CaffeineViewModel(),
        settings: SettingsModel(),
        loginItem: FakeLoginItemService()
    )
    .environment(\.locale, .init(identifier: "en"))
}
```

- [ ] **Step 2: Build to verify**

Run:

```bash
xcodebuild -scheme "Caffeine" -destination "platform=macOS" build 2>&1 | tail -30
```

Expected: `** BUILD SUCCEEDED **`. The view now references `FakeLoginItemService` in `#Preview`, so make sure Task 1's stub-or-real `FakeLoginItemService` is visible. If the build fails with `Cannot find 'FakeLoginItemService' in scope`, confirm that `src/Caffeine/Classes/Services/LoginItemService.swift` defines it (Task 1) and the synchronized group picked it up.

- [ ] **Step 3: Run `swiftformat`**

```bash
swiftformat .
```

Expected: no diff.

- [ ] **Step 4: Commit**

```bash
git add src/Caffeine/Classes/Views/GeneralSettingsView.swift
git commit -m "feat(settings): add Start at login toggle with error feedback"
```

---

## Task 5: Inject `LoginItemService` from `CaffeineApp`

**Files:**
- Modify: `src/Caffeine/Classes/CaffeineApp.swift`

- [ ] **Step 1: Add the `@State` and pass it into `GeneralSettingsView`**

In `src/Caffeine/Classes/CaffeineApp.swift`, locate the block of `@State` declarations (currently lines 14-16):

```swift
    @State private var viewModel = CaffeineViewModel()
    @State private var settings = SettingsModel()
    @State private var updater = UpdaterController()
```

Add a fourth `@State` after them:

```swift
    @State private var loginItem: any LoginItemService = .live()
```

Then, in the `Settings { TabView { ... } }` block, change the call:

```swift
                Tab(
                    String(localized: "General"),
                    systemImage: "gearshape"
                ) {
                    GeneralSettingsView(viewModel: self.viewModel, settings: self.settings)
                }
```

to:

```swift
                Tab(
                    String(localized: "General"),
                    systemImage: "gearshape"
                ) {
                    GeneralSettingsView(
                        viewModel: self.viewModel,
                        settings: self.settings,
                        loginItem: self.loginItem
                    )
                }
```

- [ ] **Step 2: Trigger `refresh()` once on first scene appearance**

Modify the `Settings { ... }` block to attach a `.task` that refreshes the login-item status when the Settings scene first appears. The final `Settings { ... }` block becomes:

```swift
        Settings {
            TabView {
                Tab(
                    String(localized: "General"),
                    systemImage: "gearshape"
                ) {
                    GeneralSettingsView(
                        viewModel: self.viewModel,
                        settings: self.settings,
                        loginItem: self.loginItem
                    )
                }

                Tab(
                    String(localized: "About"),
                    systemImage: "info.circle"
                ) {
                    AboutSettingsView(updater: self.updater)
                }
            }
            // .focusable(false)
            .frame(minWidth: 440, minHeight: 360)
        }
        .defaultSize(width: 440, height: 360)
        .task {
            await self.loginItem.refresh()
        }
```

- [ ] **Step 3: Build to verify**

Run:

```bash
xcodebuild -scheme "Caffeine" -destination "platform=macOS" build 2>&1 | tail -30
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Run `swiftformat`**

```bash
swiftformat .
```

Expected: no diff.

- [ ] **Step 5: Commit**

```bash
git add src/Caffeine/Classes/CaffeineApp.swift
git commit -m "feat(app): wire LoginItemService into Settings scene"
```

---

## Task 6: Update `CHANGELOG.md`

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Append an `### Added` block under `## [Unreleased]`**

In `CHANGELOG.md`, the `## [Unreleased]` section currently has an `### Added` block (lines 11-17) describing the new Settings window two-tab layout. **Do not modify the existing entries.** Add the new entry as a separate bullet inside the existing `### Added` block. Locate:

```markdown
### Added

- Settings window now has a two-tab layout: **General** (existing
  preferences) and **About** (app version, description, GitHub
  link, Check for Updates).
- "Check for Updates" moved from the menu bar item to the About tab.
```

Change it to:

```markdown
### Added

- Settings window now has a two-tab layout: **General** (existing
  preferences) and **About** (app version, description, GitHub
  link, Check for Updates).
- "Check for Updates" moved from the menu bar item to the About tab.
- "Start at login" preference in Settings → General. When enabled,
  Caffeine registers itself with `SMAppService.mainApp` so it
  launches automatically on user login. Default is off.
```

- [ ] **Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs(changelog): note Start at login preference"
```

---

## Task 7: Localise the new strings (en + 13 languages)

**Files:**
- Modify: `src/Caffeine/Resources/en.lproj/Localizable.strings`
- Modify: `src/Caffeine/Resources/<other 13 langs>.lproj/Localizable.strings`

- [ ] **Step 1: Add the two keys to `en.lproj/Localizable.strings`**

In `src/Caffeine/Resources/en.lproj/Localizable.strings`, locate the `/* Settings labels */` section (around lines 33-40) which contains `"Default duration"`, `"Activate when starting Caffeine"`, etc. Add the two new keys right before `"Close"` so they sit with the other Settings labels:

```strings
"Start at login" = "Start at login";
"Automatically start Caffeine when you log in to your Mac." = "Automatically start Caffeine when you log in to your Mac.";
```

The resulting `Settings labels` section reads:

```strings
/* Settings labels */
"Default duration" = "Default duration";
"Activate when starting Caffeine" = "Activate when starting Caffeine";
"Deactivate when device goes to sleep manually" = "Deactivate when device goes to sleep manually";
"Keep apps active" = "Keep apps active";
"Prevents apps from becoming inactive and the screen saver from starting." = "Prevents apps from becoming inactive and the screen saver from starting.";
"Start at login" = "Start at login";
"Automatically start Caffeine when you log in to your Mac." = "Automatically start Caffeine when you log in to your Mac.";
"Close" = "Close";
```

- [ ] **Step 2: Add the same keys to the other 13 `Localizable.strings` files**

For each of the following 13 files, append the two new keys at the same position (immediately before `"Close"` inside the `/* Settings labels */` section):

- `src/Caffeine/Resources/de.lproj/Localizable.strings`
- `src/Caffeine/Resources/es.lproj/Localizable.strings`
- `src/Caffeine/Resources/fr.lproj/Localizable.strings`
- `src/Caffeine/Resources/it.lproj/Localizable.strings`
- `src/Caffeine/Resources/ja.lproj/Localizable.strings`
- `src/Caffeine/Resources/ko.lproj/Localizable.strings`
- `src/Caffeine/Resources/nl.lproj/Localizable.strings`
- `src/Caffeine/Resources/pt.lproj/Localizable.strings`
- `src/Caffeine/Resources/pt-BR.lproj/Localizable.strings`
- `src/Caffeine/Resources/ru.lproj/Localizable.strings`
- `src/Caffeine/Resources/uk.lproj/Localizable.strings`
- `src/Caffeine/Resources/zh-Hans.lproj/Localizable.strings`

The exact translation strings for each language are listed in the **Translation table** at the bottom of this task. Add them **verbatim** — they have been chosen to match the formality and vocabulary of the existing translations in each file (e.g. zh-Hans follows the existing "默认时长" pattern; de uses the imperative style used elsewhere in that file; etc.).

- [ ] **Step 3: Confirm both keys exist in every file**

Run:

```bash
grep -l '"Start at login"' /Users/mac/zcode/Caffeine/src/Caffeine/Resources/*/Localizable.strings | wc -l
grep -l '"Automatically start Caffeine when you log in to your Mac."' /Users/mac/zcode/Caffeine/src/Caffeine/Resources/*/Localizable.strings | wc -l
```

Expected: both commands print `14`. If either prints fewer, find the missing file with `grep -L` and patch it.

- [ ] **Step 4: Build to confirm no strings file is malformed**

Run:

```bash
xcodebuild -scheme "Caffeine" -destination "platform=macOS" build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`. A malformed `.strings` file would surface here as `could not parse` or `missing semicolon`.

- [ ] **Step 5: Commit**

```bash
git add src/Caffeine/Resources/
git commit -m "feat(i18n): localise Start at login toggle across 14 languages"
```

#### Translation table (Task 7 Step 2 reference)

| Lang | `Start at login` | `Automatically start Caffeine when you log in to your Mac.` |
|---|---|---|
| de | Beim Anmelden starten | Caffeine automatisch starten, wenn Sie sich bei Ihrem Mac anmelden. |
| es | Iniciar al arrancar | Inicia Caffeine automáticamente al iniciar sesión en tu Mac. |
| fr | Lancer au démarrage | Lancez Caffeine automatiquement lorsque vous vous connectez à votre Mac. |
| it | Avvia all'accesso | Avvia Caffeine automaticamente quando accedi al tuo Mac. |
| ja | ログイン時に起動 | Mac にログインした時に Caffeine を自動的に起動します。 |
| ko | 로그인 시 시작 | Mac에 로그인할 때 Caffeine를 자동으로 시작합니다. |
| nl | Starten bij aanmelden | Start Caffeine automatisch wanneer je je aanmeldt bij je Mac. |
| pt | Iniciar ao iniciar sessão | Inicia o Caffeine automaticamente quando inicias sessão no teu Mac. |
| pt-BR | Iniciar ao fazer login | Inicia o Caffeine automaticamente quando você faz login no seu Mac. |
| ru | Запускать при входе | Автоматически запускать Caffeine при входе в систему на вашем Mac. |
| uk | Запускати під час входу | Автоматично запускати Caffeine під час входу в систему на вашому Mac. |
| zh-Hans | 开机时启动 | 在登录 Mac 时自动启动 Caffeine。 |

---

## Task 8: Create test file `LoginItemServiceTests.swift` (follow-up only — needs a test target)

**Files:**
- Create: `src/Caffeine/Classes/Services/LoginItemServiceTests.swift`

> **Important:** This task is a **follow-up**. The file is created so the test code is reviewable in the same change, but it will not run until a test target exists in `.xcodeproj`. Per `AGENTS.md`, editing `.xcodeproj` requires explicit user permission — flag it to the user at the end of the task rather than attempting it yourself.

- [ ] **Step 1: Create the test file**

Write the following to `src/Caffeine/Classes/Services/LoginItemServiceTests.swift`:

```swift
//
//  LoginItemServiceTests.swift
//  Caffeine
//
//  Tests for the in-memory `FakeLoginItemService`. Will be picked up
//  once an XCTest target is added to the project (follow-up — adding
//  a target requires editing `.xcodeproj`, which is forbidden without
//  explicit user permission per AGENTS.md).
//

import XCTest

@MainActor
final class LoginItemServiceTests: XCTestCase {
    func testSetEnabledTrueFlipsStatusToEnabled() async throws {
        let service = FakeLoginItemService(initialStatus: .disabled)

        try await service.setEnabled(true)

        XCTAssertEqual(service.status, .enabled)
    }

    func testSetEnabledFalseFlipsStatusToDisabled() async throws {
        let service = FakeLoginItemService(initialStatus: .enabled)

        try await service.setEnabled(false)

        XCTAssertEqual(service.status, .disabled)
    }

    func testSetEnabledTrueWithForcedUnderlyingErrorThrowsAndLeavesStatusUnchanged() async {
        let service = FakeLoginItemService(initialStatus: .disabled)
        service.setNextError { .underlying("synthetic") }

        do {
            try await service.setEnabled(true)
            XCTFail("Expected throw")
        } catch let error as LoginItemError {
            switch error {
            case let .underlying(message):
                XCTAssertEqual(message, "synthetic")
            case .userCancelled:
                XCTFail("Expected .underlying, got .userCancelled")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }

        XCTAssertEqual(service.status, .disabled)
    }

    func testSetEnabledFalseWithForcedUnderlyingErrorThrowsAndLeavesStatusUnchanged() async {
        let service = FakeLoginItemService(initialStatus: .enabled)
        service.setNextError { .underlying("synthetic") }

        do {
            try await service.setEnabled(false)
            XCTFail("Expected throw")
        } catch let error as LoginItemError {
            switch error {
            case let .underlying(message):
                XCTAssertEqual(message, "synthetic")
            case .userCancelled:
                XCTFail("Expected .underlying, got .userCancelled")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }

        XCTAssertEqual(service.status, .enabled)
    }

    func testForcedErrorIsConsumedAfterOneInvocation() async throws {
        let service = FakeLoginItemService()
        service.setNextError { .underlying("once") }

        do {
            try await service.setEnabled(true)
            XCTFail("Expected throw on first call")
        } catch {
            // expected
        }

        // Second call should succeed because the injected factory was
        // consumed.
        try await service.setEnabled(true)
        XCTAssertEqual(service.status, .enabled)
    }

    func testRefreshIsNoOpForFake() async {
        let service = FakeLoginItemService(initialStatus: .requiresApproval)

        await service.refresh()

        XCTAssertEqual(service.status, .requiresApproval)
    }

    func testLoginItemErrorErrorDescription() {
        XCTAssertNotNil(LoginItemError.underlying("x").errorDescription)
        XCTAssertNotNil(LoginItemError.userCancelled.errorDescription)
    }
}
```

- [ ] **Step 2: Build the app target to confirm the file compiles**

Run:

```bash
xcodebuild -scheme "Caffeine" -destination "platform=macOS" build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`. The test file is not part of the app target, but the synchronized group **may** include it; if the app target tries to compile it as a regular source, the build will fail because `XCTest` symbols are not linked into the app.

If the build fails with `XCTestCase` not found or similar, **move the test file out of the synchronized group** by changing its extension: rename it to `LoginItemServiceTests.swift.disabled` (or simply leave it out of the synchronized root) and note in the commit message that it is parked pending a test target.

The simplest robust approach: place the file under `src/Caffeine/Classes/Services/LoginItemServiceTests.swift` but **rename it** to `LoginItemServiceTests.swift.disabled` (or place it in a `Tests/` subdirectory that is not part of the synchronized root) if the build fails. The implementation plan accepts either outcome as long as the app target builds.

- [ ] **Step 3: Run `swiftformat`**

```bash
swiftformat .
```

Expected: no diff.

- [ ] **Step 4: Commit**

```bash
git add src/Caffeine/Classes/Services/LoginItemServiceTests.swift
git commit -m "test(login): add LoginItemServiceTests (follow-up; needs test target)"
```

If the file was renamed to `.disabled` in Step 2, adjust the `git add` path accordingly.

- [ ] **Step 5: Flag the follow-up to the user**

Output to the user:

> The test file `LoginItemServiceTests.swift` is in place but will not run until an XCTest target is added to the Xcode project. Adding a target requires editing `.xcodeproj/project.pbxproj`, which `AGENTS.md` forbids without explicit permission. The production code (`FakeLoginItemService`) is fully unit-testable once the target exists.

---

## Task 9: Final verification

**Files:** (no changes — read-only verification)

- [ ] **Step 1: Clean and build from scratch**

```bash
xcodebuild -scheme "Caffeine" -destination "platform=macOS" clean
xcodebuild -scheme "Caffeine" -destination "platform=macOS" build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

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
src/Caffeine/Classes/Services/LoginItemService.swift
src/Caffeine/Classes/Services/LoginItemServiceTests.swift
src/Caffeine/Classes/ViewModels/CaffeineViewModel.swift
src/Caffeine/Classes/Views/AboutSettingsView.swift
src/Caffeine/Classes/Views/GeneralSettingsView.swift
src/Caffeine/Classes/Views/MenuBarContentView.swift
```

If `LoginItemServiceTests.swift` was renamed to `.disabled` in Task 8 Step 2, it appears as `LoginItemServiceTests.swift.disabled`.

- [ ] **Step 4: Verify git history is clean and atomic**

```bash
git log --oneline -10
```

Expected: the most recent commits match the commits made in Tasks 1-8.

- [ ] **Step 5: Manual smoke check (user-driven)**

This task cannot be automated. Hand the build to the user with these checks:

1. Launch the app from Xcode.
2. Open Settings from the menu bar (Settings...).
3. On the General tab, confirm the new "Start at login" toggle exists below "Deactivate when device goes to sleep manually" and above "Keep apps active". It defaults to off.
4. Confirm the secondary help text "Automatically start Caffeine when you log in to your Mac." is shown below the toggle.
5. Toggle **on**. macOS shows the standard system authorisation prompt for Login Items. Approve it.
6. Open System Settings → General → Login Items. "Caffeine" should appear in the "Open at Login" list.
7. Toggle **off** in our app. "Caffeine" should disappear from the Login Items list.
8. Toggle **on** again, then **deny** the system prompt. The toggle should revert to off and a red one-line error message "Couldn't change login item setting." should appear below the toggle.
9. Quit the app, then log out and back in (or restart the Mac). Confirm Caffeine launches silently — the menu bar icon should appear and (if "Activate when starting Caffeine" is also on) Caffeine should be active.
10. Verify the "Activate when starting Caffeine" and "Keep apps active" toggles still behave as they did before this change (regression check).

If any check fails, the most likely cause is `SMAppService` API surface drift between SDKs — see the fallback note in Task 2 Step 3.

---

## Self-Review

**1. Spec coverage:**

| Spec section | Implemented in |
|---|---|
| `SMAppService.mainApp` integration | Task 2 |
| `LoginItemService` protocol + `LiveLoginItemService` | Tasks 1, 2 |
| `FakeLoginItemService` for tests | Task 1 |
| `LoginItemStatus` and `LoginItemError` enums | Task 1 |
| `SettingsModel.startAtLogin` + `PreferenceKeys.startAtLogin` | Task 3 |
| `GeneralSettingsView` toggle + error feedback | Task 4 |
| `CaffeineApp` injection + one-time `refresh()` | Task 5 |
| `CHANGELOG.md` entry | Task 6 |
| Localisation (en + 13 languages) | Task 7 |
| Test file (follow-up pending test target) | Task 8 |
| Build + swiftformat + manual verification | Task 9 |

All sections covered.

**2. Placeholder scan:** No `TBD` / `TODO` / "similar to Task N" / "implement later" / "add appropriate error handling" in any task. Every code block is complete. Translation strings are spelled out verbatim in Task 7's table.

**3. Type consistency:**
- `LoginItemService` protocol declared in Task 1 (status, refresh, setEnabled); `LiveLoginItemService` conforms in Task 2; `FakeLoginItemService` conforms in Task 1; referenced by `GeneralSettingsView` in Task 4 with parameter name `loginItem`; injected by `CaffeineApp` in Task 5 as `@State private var loginItem: any LoginItemService = .live()`. All consistent.
- `SettingsModel.startAtLogin` declared in Task 3, referenced via `self.settings.startAtLogin` in Tasks 4 and reverted in `applyLoginItemChange`.
- `PreferenceKeys.startAtLogin = "CAStartAtLogin"` declared in Task 3, used in Tasks 3, 4.
- `LoginItemError.errorDescription` returns the English fallback string (per spec's "Out of scope: error message localisation").

No issues found.
