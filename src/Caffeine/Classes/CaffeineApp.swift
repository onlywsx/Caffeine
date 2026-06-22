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

    @State private var settings: SettingsModel
    @State private var viewModel: CaffeineViewModel

    init() {
        let settings = SettingsModel()
        self._settings = State(initialValue: settings)
        self._viewModel = State(initialValue: CaffeineViewModel(settings: settings))
    }

    @State private var updater = UpdaterController()

    var body: some Scene {
        // macOS 27 recommended menu bar API. Renders the
        // `active` / `inactive` template image as the icon and
        // shows `MenuBarContentView` on left- or right-click.
        MenuBarExtra {
            MenuBarContentView(updater: self.updater)
                .environment(self.viewModel)
        } label: {
            Image(self.viewModel.isActive ? "active" : "inactive")
        }
        .menuBarExtraStyle(.menu)

        // Native macOS Settings scene with a tabbed layout. The
        // system owns the title bar, tab chrome, and appearance
        // following.
        //
        // `.defaultSize()` sets the initial window size. The
        // previous `.frame(minWidth:)` only constrained the
        // content, not the window itself, so the window could
        // open wider than 480.
        Settings {
            TabView {
                Tab(
                    String(localized: "General"),
                    systemImage: "gearshape"
                ) {
                    GeneralSettingsView()
                        .environment(self.settings)
                }

                Tab(
                    String(localized: "Power"),
                    systemImage: "bolt"
                ) {
                    PowerSettingsView()
                        .environment(self.settings)
                }

                Tab(
                    String(localized: "Keyboard"),
                    systemImage: "keyboard"
                ) {
                    KeyboardSettingsView()
                        .environment(self.settings)
                }

                Tab(
                    String(localized: "About"),
                    systemImage: "info.circle"
                ) {
                    AboutSettingsView(updater: self.updater)
                }
            }
            // .focusable(false)
            .frame(minWidth: 440, minHeight: 400)
            .environment(self.viewModel)
        }
        .defaultSize(width: 440, height: 400)
    }
}
