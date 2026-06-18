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
        //
        // Tabs are bound to a `SettingsTab` selection so we can
        // pass a plain `LocalizedStringKey` title without a
        // `systemImage:`. The system `Tab(_:systemImage:)` API
        // wraps every icon in a soft icon-container background
        // even when the tab is unselected, which reads as a
        // glow / pill around every icon. Text-only labels keep
        // the tab bar minimal and match the system Settings
        // window's compact two-tab layout.
        Settings {
            TabView {
                Tab {
                    GeneralSettings(viewModel: self.viewModel, settings: self.settings)
                } label: {
                    Text("General")
                }

                Tab {
                    AboutSettings(updater: self.updater)
                } label: {
                    Text("About")
                }
            }
            .frame(minWidth: 480, minHeight: 360)
        }
    }
}
