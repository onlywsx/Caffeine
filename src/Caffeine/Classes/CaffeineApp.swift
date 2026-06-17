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
    @State private var updater = UpdaterController()

    @Environment(\.openSettings)
    private var openSettings

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

        Settings {
            PreferencesView(viewModel: self.viewModel, updater: self.updater)
                .task {
                    // First-launch welcome screen — surfaces the
                    // preferences window on the very first run
                    // (when the user has not dismissed the
                    // message yet). The flag is read here rather
                    // than inside `viewModel.init` so that we
                    // have access to the `openSettings` action
                    // from the SwiftUI environment.
                    if self.viewModel.showPreferences {
                        NSApp.activate(ignoringOtherApps: true)
                        self.openSettings()
                        self.viewModel.showPreferences = false
                    }
                }
        }
    }
}
