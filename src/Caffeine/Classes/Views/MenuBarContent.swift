//
//  MenuBarContent.swift
//  Caffeine
//
//  Created by Dominic Rodemer on 11.11.25.
//

import Sparkle
import SwiftUI

/// SwiftUI menu bar content for the `MenuBarExtra` scene.
///
/// On macOS 27, `MenuBarExtra` is the recommended way to add a
/// menu bar item. It handles left- and right-click uniformly — both
/// surface the same menu — which sidesteps the macOS 27
/// `NSStatusBarButton` right-mouse regression that previously
/// required a session-level `CGEventTap` and accessibility
/// permission.
struct MenuBarContent: View {
    @Bindable var viewModel: CaffeineViewModel
    let updater: UpdaterController

    @Environment(\.openSettings)
    private var openSettings

    var body: some View {
        // Status row — read-only indicator of the current
        // activation state.  Only visible when Caffeine is active.
        if let status = viewModel.formattedTimeRemaining() {
            Text(status)
                .foregroundStyle(.secondary)
        }

        Divider()

        // Primary toggle action
        Button {
            self.viewModel.toggleActive()
        } label: {
            Text(self.viewModel.isActive
                ? String(localized: "Deactivate Caffeine")
                : String(localized: "Activate Caffeine"))
        }

        // "Activate for…" durations submenu
        Menu(String(localized: "Activate for")) {
            ForEach(Self.durations, id: \.minutes) { entry in
                Button(entry.title) {
                    self.viewModel.activate(withTimeout: entry.minutes > 0 ? TimeInterval(entry.minutes * 60) : 0)
                }
            }
            #if DEBUG
            Button(String(localized: "1 minute")) {
                self.viewModel.activate(withTimeout: 60)
            }
            #endif
        }

        Divider()

        Button(String(localized: "Preferences...")) {
            NSApp.activate(ignoringOtherApps: true)
            self.openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Button(String(localized: "Check for Updates...")) {
            self.updater.checkForUpdates()
        }

        Divider()

        Button(String(localized: "Quit")) {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    /// Standard duration choices. `0` means "indefinite".
    private struct DurationEntry {
        let title: String
        let minutes: Int
    }

    private static let durations: [DurationEntry] = [
        DurationEntry(title: String(localized: "Indefinitely"), minutes: 0),
        DurationEntry(title: String(localized: "5 minutes"), minutes: 5),
        DurationEntry(title: String(localized: "10 minutes"), minutes: 10),
        DurationEntry(title: String(localized: "15 minutes"), minutes: 15),
        DurationEntry(title: String(localized: "30 minutes"), minutes: 30),
        DurationEntry(title: String(localized: "1 hour"), minutes: 60),
        DurationEntry(title: String(localized: "2 hours"), minutes: 120),
        DurationEntry(title: String(localized: "5 hours"), minutes: 300),
    ]
}

/// Thin `@Observable` wrapper around `SPUStandardUpdaterController`
/// so the menu can call `checkForUpdates()` from a SwiftUI
/// environment value without forcing the menu to know about
/// AppKit or Sparkle directly.
@MainActor
@Observable
final class UpdaterController {
    private let controller: SPUStandardUpdaterController

    init() {
        self.controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        self.controller.checkForUpdates(nil)
    }
}
