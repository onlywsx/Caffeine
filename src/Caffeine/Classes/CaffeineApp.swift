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
    @State private var loginItem: any LoginItemService = LiveLoginItemService()

    var body: some Scene {
        // macOS 27 recommended menu bar API. Renders the
        // `active` / `inactive` template image as the icon and
        // shows `MenuBarContentView` on left- or right-click.
        MenuBarExtra {
            MenuBarContentView(viewModel: self.viewModel, updater: self.updater)
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
                    GeneralSettingsView(
                        viewModel: self.viewModel,
                        settings: self.settings,
                        loginItem: self.loginItem
                    )
                }

                Tab(
                    String(localized: "Power"),
                    systemImage: "bolt"
                ) {
                    PowerSettingsView(
                        viewModel: self.viewModel,
                        settings: self.settings
                    )
                }

                Tab(
                    String(localized: "Keyboard"),
                    systemImage: "keyboard"
                ) {
                    KeyboardSettingsView(
                        viewModel: self.viewModel,
                        settings: self.settings
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
            .frame(minWidth: 440, minHeight: 400)
            .task {
                await self.loginItem.refresh()
            }
        }
        .defaultSize(width: 440, height: 400)
    }
}
