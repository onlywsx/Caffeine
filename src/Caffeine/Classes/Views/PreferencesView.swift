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
            GeneralSettingsView(viewModel: self.viewModel)
                .tabItem {
                    Label(String(localized: "General", comment: "Settings tab: General"), systemImage: "gearshape")
                }

            AboutView(updater: self.updater)
                .tabItem {
                    Label(String(localized: "About", comment: "Settings tab: About"), systemImage: "info.circle")
                }
        }
        .frame(minWidth: 680, minHeight: 520)
    }
}

#Preview {
    PreferencesView(viewModel: CaffeineViewModel(), updater: UpdaterController())
        .environment(\.locale, .init(identifier: "en"))
}
