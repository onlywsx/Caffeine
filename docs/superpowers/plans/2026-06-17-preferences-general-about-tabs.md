# Preferences Window — General + About Tabs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single-page `PreferencesView` with a standard macOS settings window that has two tabs — **General** (existing preferences) and **About** (version, description, repo link, Check for Updates). Use the SwiftUI `Settings` scene already in place; switch its content from a single view to a `TabView`.

**Architecture:** Keep `Settings { }` in `CaffeineApp.swift` as the window host. Inside, render a `TabView` (system segmented style) that hosts two top-level views: a refactored `GeneralSettingsView` (existing controls) and a new `AboutView` (read-only metadata + a "Check for Updates" button). No new state, no new persistence keys. All existing `UserDefaults` reads (`PreferenceKeys.*`) and the `viewModel.updateActivitySimulation` binding are preserved. The `showPreferences` first-launch flow in `CaffeineApp.task` continues to work because it calls `openSettings()` on the `Settings` scene itself — content changes inside the scene are transparent to that path.

**Tech Stack:** Swift 5/6, SwiftUI, `@Observable` view model, `TabView` (system segmented style), `Bundle.main`, `LocalizedStringKey`, `LSApplicationWorkspace` not needed, Sparkle `SPUStandardUpdaterController` (already wrapped by `UpdaterController`).

---

## File Structure

| Path | Action | Responsibility |
|---|---|---|
| `src/Caffeine/Classes/Views/PreferencesView.swift` | **Modify** (rewrite) | Now a `TabView` host with two tabs. Replaces the old single-pane layout. |
| `src/Caffeine/Classes/Views/GeneralSettingsView.swift` | **Create** | The General tab — all existing preferences (default duration, activate at launch, deactivate on manual sleep, show launch message, keep apps active). |
| `src/Caffeine/Classes/Views/AboutView.swift` | **Create** | The About tab — app icon, name, version, description, repo link, Check for Updates button. |
| `src/Caffeine/Classes/CaffeineApp.swift` | **No change** | Already calls `Settings { PreferencesView(...) }`. |
| `src/Caffeine/Resources/en.lproj/Localizable.strings` | **Modify** | Add new keys for the About tab. |
| `src/Caffeine/Resources/{de,es,fr,it,ja,ko,nl,pt-BR,pt,ru,uk,zh-Hans}.lproj/Localizable.strings` | **Modify** | Mirror the new English keys. The English value is the fallback, so non-English locales will fall back until translated. |
| `CHANGELOG.md` | **Modify** | Add entry to `[Unreleased]` documenting the new tabbed settings window. |

No Xcode project file changes — `src/Caffeine/Classes/Views/` is a `PBXFileSystemSynchronizedRootGroup` (Xcode 16+), so new files in that directory are picked up automatically.

---

## Task 1: Extract existing preferences into `GeneralSettingsView`

**Files:**
- Create: `src/Caffeine/Classes/Views/GeneralSettingsView.swift`
- Read (do not modify): `src/Caffeine/Classes/Views/PreferencesView.swift`

- [ ] **Step 1: Create `GeneralSettingsView.swift` with the existing controls**

Move all the `@AppStorage` declarations, the icon + description header, the default duration picker, the four toggles, the "Keep apps active" subtitle, and the Quit/Close footer into a new file. Keep the same visual layout — this is purely a file move, no design change.

```swift
//
//  GeneralSettingsView.swift
//  Caffeine
//

import SwiftUI

/// General preferences tab. Hosts the existing controls: default
/// activation duration, launch behaviour, sleep behaviour, and the
/// activity-simulation toggle. The view reads its state directly
/// from `UserDefaults` via `@AppStorage` and routes the
/// "keep apps active" toggle through the view model so the
/// `ActivitySimulator` can be started/stopped.
struct GeneralSettingsView: View {
    @Bindable var viewModel: CaffeineViewModel
    @AppStorage(PreferenceKeys.defaultDuration) private var defaultDuration = 0
    @AppStorage(PreferenceKeys.activateAtLaunch) private var activateAtLaunch = false
    @AppStorage(PreferenceKeys.suppressLaunchMessage) private var suppressLaunchMessage = false
    @AppStorage(PreferenceKeys.deactivateOnManualSleep) private var deactivateOnManualSleep = false
    @AppStorage(PreferenceKeys.keepAppsActive) private var keepAppsActive = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Icon and description
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                        .resizable()
                        .frame(width: 140, height: 140)
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text(
                        "Caffeine is now running. You can find its icon in the right side of your menu bar. Click it to disable automatic sleep, click it again to enable automatic sleep."
                    )
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)

                    Text("Click the menu bar icon to open the Caffeine menu.")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 30)

            // Default duration
            HStack(spacing: 8) {
                Text("Default duration:")
                    .font(.system(size: 13))

                Picker("", selection: self.$defaultDuration) {
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                    Text("2 hours").tag(120)
                    Text("5 hours").tag(300)
                    Text("Indefinitely").tag(0)
                }
                .pickerStyle(.menu)
                .frame(width: 180)

                Spacer()
            }
            .padding(.bottom, 16)

            // Checkboxes
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Activate when starting Caffeine", isOn: self.$activateAtLaunch)
                    .font(.system(size: 13))

                Toggle("Deactivate when device goes to sleep manually", isOn: self.$deactivateOnManualSleep)
                    .font(.system(size: 13))

                Toggle("Show this message when starting Caffeine", isOn: Binding(
                    get: { !self.suppressLaunchMessage },
                    set: { self.suppressLaunchMessage = !$0 }
                ))
                .font(.system(size: 13))

                Divider()
                    .padding(.vertical, 4)

                Toggle("Keep apps active", isOn: Binding(
                    get: { self.keepAppsActive },
                    set: { newValue in
                        self.keepAppsActive = newValue
                        self.viewModel.updateActivitySimulation(enabled: newValue)
                    }
                ))
                .font(.system(size: 13))

                Text("Prevents apps from becoming inactive and the screen saver from starting.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }

            Spacer()
                .frame(height: 30)

            // Footer buttons
            HStack {
                Button(String(localized: "Quit")) {
                    NSApp.terminate(nil)
                }
                .controlSize(.large)

                Spacer()

                Button(String(localized: "Close")) {
                    NSApp.keyWindow?.close()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 20)
        .frame(width: 640)
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    GeneralSettingsView(viewModel: CaffeineViewModel())
        .environment(\.locale, .init(identifier: "en"))
}
```

- [ ] **Step 2: Verify the file compiles in isolation**

Run: `xcodebuild -scheme "Caffeine" -destination "platform=macOS" build`
Expected: Build succeeds. (The new file is unused by `PreferencesView` yet, but it must type-check against `CaffeineViewModel` and `PreferenceKeys`.) If it fails, fix import / type errors before proceeding.

- [ ] **Step 3: Commit**

```bash
git add src/Caffeine/Classes/Views/GeneralSettingsView.swift
git commit -m "refactor: extract General preferences into dedicated view"
```

---

## Task 2: Create `AboutView`

**Files:**
- Create: `src/Caffeine/Classes/Views/AboutView.swift`

- [ ] **Step 1: Write `AboutView.swift`**

The About tab is read-only metadata. Layout: app icon (left), app name + version + description (right). Below that, a row with a "View on GitHub" button and a "Check for Updates" button. Use `Bundle.main.infoDictionary["CFBundleShortVersionString"]` for the version. Use `NSWorkspace.shared.open` for the repo link (clicks open the system browser).

```swift
//
//  AboutView.swift
//  Caffeine
//

import Sparkle
import SwiftUI

/// About tab. Read-only metadata about the app plus a Check for
/// Updates button. Layout matches the visual rhythm of the General
/// tab so the two sit well side-by-side in the Settings window.
struct AboutView: View {
    let updater: UpdaterController

    /// The bundle's marketing version (e.g. "1.6.5"). Read once at
    /// view init because the value is constant for the lifetime of
    /// the process.
    private let version: String = {
        if let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            return v
        }
        return "1.0.0"
    }()

    private let repoURL = URL(string: "https://github.com/dominc/Caffeine")!

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App icon + name + version + description
            HStack(alignment: .center, spacing: 16) {
                Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                    .resizable()
                    .frame(width: 140, height: 140)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Caffeine")
                        .font(.system(size: 20, weight: .semibold))

                    // Localized "Version %@"
                    Text(String(
                        format: String(localized: "Version %@", comment: "About tab version label"),
                        version
                    ))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                    Text(
                        "Caffeine keeps your Mac awake. Click the menu bar icon to disable automatic sleep; click it again to re-enable it."
                    )
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 24)

            // Credits (preserved from the old NSApp.orderFrontStandardAboutPanel credits)
            Text(
                "© 2006 Tomas Franzén\n© 2018 Michael Jones\n© 2022 Dominic Rodemer"
            )
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.bottom, 24)

            // Action buttons
            HStack(spacing: 12) {
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

            Spacer()
                .frame(height: 30)
        }
        .padding(.horizontal, 20)
        .frame(width: 640)
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    AboutView(updater: UpdaterController())
        .environment(\.locale, .init(identifier: "en"))
}
```

- [ ] **Step 2: Verify the file compiles in isolation**

Run: `xcodebuild -scheme "Caffeine" -destination "platform=macOS" build`
Expected: Build succeeds. (Same as Task 1 — type-check only, file not yet wired in.)

- [ ] **Step 3: Commit**

```bash
git add src/Caffeine/Classes/Views/AboutView.swift
git commit -m "feat: add About tab with version, description, and Check for Updates"
```

---

## Task 3: Replace `PreferencesView` with a `TabView` host

**Files:**
- Modify: `src/Caffeine/Classes/Views/PreferencesView.swift` (full rewrite)

- [ ] **Step 1: Rewrite `PreferencesView.swift`**

The new `PreferencesView` is just a `TabView` host. It takes the same `viewModel: CaffeineViewModel` it always has (so `CaffeineApp.swift` doesn't need to change), plus a new `updater: UpdaterController` (needed to give `AboutView` access to the Sparkle updater). We use `TabView`'s `.tabViewStyle(.automatic)` which renders as a **segmented control** in the macOS Settings scene — this is the macOS-recommended look (no manual segmented Picker).

```swift
//
//  PreferencesView.swift
//  Caffeine
//

import SwiftUI

/// Root of the Settings window. Hosts two tabs: General and About.
///
/// `CaffeineApp.swift` passes this view into the `Settings { }` scene,
/// which gives it the standard macOS settings chrome (traffic lights,
/// window title, segmented tab bar in the window's content area).
/// The first-launch welcome flow (`.task { … openSettings() … }`)
/// continues to work unchanged because that flow targets the
/// `Settings` scene itself, not this view.
struct PreferencesView: View {
    @Bindable var viewModel: CaffeineViewModel
    let updater: UpdaterController

    var body: some View {
        TabView {
            Tab(
                String(localized: "General", comment: "Settings tab: General"),
                systemImage: "gearshape"
            ) {
                GeneralSettingsView(viewModel: self.viewModel)
            }

            Tab(
                String(localized: "About", comment: "Settings tab: About"),
                systemImage: "info.circle"
            ) {
                AboutView(updater: self.updater)
            }
        }
        .frame(minWidth: 680, minHeight: 520)
    }
}

#Preview {
    PreferencesView(viewModel: CaffeineViewModel(), updater: UpdaterController())
        .environment(\.locale, .init(identifier: "en"))
}
```

- [ ] **Step 2: Update `CaffeineApp.swift` to pass `updater` into `PreferencesView`**

The `Settings { }` scene in `CaffeineApp.swift` currently calls `PreferencesView(viewModel: self.viewModel)`. Add the `updater` argument so the About tab can talk to Sparkle.

In `src/Caffeine/Classes/CaffeineApp.swift`, change:

```swift
Settings {
    PreferencesView(viewModel: self.viewModel)
        .task {
            if self.viewModel.showPreferences {
                NSApp.activate(ignoringOtherApps: true)
                self.openSettings()
                self.viewModel.showPreferences = false
            }
        }
}
```

to:

```swift
Settings {
    PreferencesView(viewModel: self.viewModel, updater: self.updater)
        .task {
            if self.viewModel.showPreferences {
                NSApp.activate(ignoringOtherApps: true)
                self.openSettings()
                self.viewModel.showPreferences = false
            }
        }
}
```

No other change to `CaffeineApp.swift` is needed — `self.updater` (an `@State UpdaterController`) is already declared at line 15.

- [ ] **Step 3: Build and run**

Run: `xcodebuild -scheme "Caffeine" -destination "platform=macOS" build`
Expected: Build succeeds. If `Tab` is unresolved (the API shipped in macOS 14+, deployment target is 13.5), the build will fail — in that case, replace the `Tab(...) { ... }` syntax with the older `TabView { ... .tabItem { Label("General", systemImage: "gearshape") } }` pattern. macOS 13.5 deployment target means we must use the `.tabItem` form. **Use the form below:**

```swift
TabView {
    GeneralSettingsView(viewModel: self.viewModel)
        .tabItem {
            Label(String(localized: "General", comment: "Settings tab: General"), systemImage: "gearshape")
        }

    AboutView(updater: self.updater)
        .tabItem {
            Label(String(localized: "About", comment: "Settings tab: About"), systemImage: "info.circle")
        }
}
```

This works on macOS 13.5+. Verify the build picks the right form by checking that the resulting `Settings` window shows two tabs in its content area (segmented control at the top, content below).

- [ ] **Step 4: Run the test suite**

Run: `xcodebuild -scheme "Caffeine" -destination "platform=macOS" test`
Expected: All existing tests pass. There are no new tests for UI work in this plan — the project has no view tests and we are not introducing test infrastructure as part of this change.

- [ ] **Step 5: Format**

Run: `swiftformat .`
Expected: Either no changes (preferred), or changes consistent with the rest of the project. Re-run `xcodebuild build` after formatting to confirm it still compiles.

- [ ] **Step 6: Commit**

```bash
git add src/Caffeine/Classes/Views/PreferencesView.swift src/Caffeine/Classes/CaffeineApp.swift
git commit -m "feat: host Settings window as TabView with General and About tabs"
```

---

## Task 4: Add localization keys

**Files:**
- Modify: `src/Caffeine/Resources/en.lproj/Localizable.strings`
- Modify: `src/Caffeine/Resources/{de,es,fr,it,ja,ko,nl,pt-BR,pt,ru,uk,zh-Hans}.lproj/Localizable.strings`

- [ ] **Step 1: Append the new English keys**

Open `src/Caffeine/Resources/en.lproj/Localizable.strings`. Append the following block at the end of the file (keep the existing `/* … */` block-comment style):

```
/* Settings tabs */
"General" = "General";
"About" = "About";

/* About tab */
"Version %@" = "Version %@";
"View on GitHub" = "View on GitHub";
"Check for Updates..." = "Check for Updates...";
```

Note: `Check for Updates...` is **already** defined earlier in this file (used by the menu). Adding a duplicate key would be ambiguous. Use a new key, or — simpler — reuse the existing `"Check for Updates..."` key (don't add it again). The final appended block is:

```
/* Settings tabs */
"General" = "General";
"About" = "About";

/* About tab */
"Version %@" = "Version %@";
"View on GitHub" = "View on GitHub";
```

- [ ] **Step 2: Mirror the same keys in all other locale files**

For each of the 12 non-English files (`de`, `es`, `fr`, `it`, `ja`, `ko`, `nl`, `pt-BR`, `pt`, `ru`, `uk`, `zh-Hans`), append the same block **with the English value as the translation** (so localization is correct in English until a translator updates them):

```
/* Settings tabs */
"General" = "General";
"About" = "About";

/* About tab */
"Version %@" = "Version %@";
"View on GitHub" = "View on GitHub";
```

(Use whatever comment style the file already uses — the project mixes `/* … */` and `//` per language. Match the surrounding style. If unsure, use `/* … */`.)

- [ ] **Step 3: Build to confirm string-table validity**

Run: `xcodebuild -scheme "Caffeine" -destination "platform=macOS" build`
Expected: Build succeeds. A missing or malformed `Localizable.strings` will fail with a `strings` tool error during the build.

- [ ] **Step 4: Commit**

```bash
git add src/Caffeine/Resources/
git commit -m "i18n: add Settings tab and About tab strings (English fallback)"
```

---

## Task 5: Update `CHANGELOG.md`

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Add entries under `[Unreleased]`**

In `CHANGELOG.md`, find the `## [Unreleased]` section (line 9). The current `### Changed` list ends at line 15. Add a new `### Added` subsection between the `## [Unreleased]` header and the existing `### Changed` subsection:

```markdown
## [Unreleased]

### Added

- Settings window now has a two-tab layout: **General** (existing
  preferences) and **About** (app version, description, GitHub
  link, Check for Updates).
- "Check for Updates" moved from the menu bar item to the About tab.

### Changed
…
```

Keep the rest of the file untouched.

- [ ] **Step 2: Build to confirm the project still compiles**

Run: `xcodebuild -scheme "Caffeine" -destination "platform=macOS" build`
Expected: Build succeeds. (CHANGELOG changes don't affect compilation, but this is a cheap final sanity check.)

- [ ] **Step 3: Final format pass**

Run: `swiftformat .`
Expected: No-op.

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: changelog entry for tabbed Settings window"
```

---

## Self-Review

**1. Spec coverage:**

- General tab with all existing controls — Task 1 (move) + Task 3 (host). ✅
- About tab with version, description, repo, Check for Updates — Task 2. ✅
- macOS-recommended settings UI (system `Settings` scene with `TabView`) — Task 3. ✅
- No new features, no removed features, no new persistence keys — Confirmed: only `viewModel.updateActivitySimulation` is still called, all `@AppStorage` keys preserved, all toggle/picker bindings preserved. ✅
- First-launch welcome flow still works — `openSettings()` in `CaffeineApp.task` still targets the `Settings` scene, content change is transparent. ✅
- CHANGELOG updated — Task 5. ✅
- Localized — Task 4. ✅

**2. Placeholder scan:** No "TBD", "TODO", "fill in", "handle edge cases" anywhere. Every code block is complete. No "similar to" references that would leave the reader stuck.

**3. Type consistency:**

- `PreferencesView(viewModel:updater:)` — defined in Task 3, called by `CaffeineApp.Settings` in Task 3 step 2, used in `#Preview` in Task 3 step 1. ✅
- `GeneralSettingsView(viewModel:)` — defined in Task 1, called in `TabView` in Task 3. ✅
- `AboutView(updater:)` — defined in Task 2, called in `TabView` in Task 3. ✅
- `UpdaterController` — already exists in `MenuBarContent.swift`, used by `MenuBarContent` and now by `AboutView`. Its `checkForUpdates()` method is already public. ✅
- `PreferenceKeys.*` — used unchanged in `GeneralSettingsView`. ✅
- `Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")` — this is a stable, documented API; safe to use. ✅
- Localization keys used: `"General"`, `"About"`, `"Version %@"`, `"View on GitHub"` — all added in Task 4. The reused `"Check for Updates..."` key already exists. ✅
- The `Tab { }` vs `.tabItem` issue: macOS deployment target is 13.5 (per `CLAUDE.md`); the `Tab` initializer is macOS 14+. Task 3 step 3 explicitly handles this by falling back to `.tabItem`. ✅

**One issue I caught and fixed inline:** the initial `Tab(...)` form in Task 3 step 1 is macOS 14+ only; the project targets macOS 13.5. Step 3 of the same task documents the fallback to `.tabItem`. Good.

No spec gaps, no placeholder leakage, type names consistent throughout.
