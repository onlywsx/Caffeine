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