//
//  PreferencesView.swift
//  Caffeine
//

import SwiftUI

/// Root of the Settings window. Hosts two tabs: General and About.
///
/// `CaffeineApp.swift` passes this view into the `Settings { }`
/// scene. Uses the macOS 15+ `Tab` initializer (rather than the
/// older `.tabItem` modifier) so the segmented control follows
/// the system light/dark theme live. Deployment target is 15.6.
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
        .frame(minWidth: 520, minHeight: 320)
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button(String(localized: "Quit")) {
                    NSApp.terminate(nil)
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Close")) {
                    NSApp.keyWindow?.close()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}

#Preview {
    PreferencesView(viewModel: CaffeineViewModel(), updater: UpdaterController())
        .environment(\.locale, .init(identifier: "en"))
}
