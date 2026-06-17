//
//  PreferencesView.swift
//  Caffeine
//

import SwiftUI

/// Root of the Settings window. Hosts two tabs: General and About.
///
/// Uses a Picker(.segmented) for the tab bar so it follows the
/// system light/dark theme live. Tab content is rendered with
/// conditional `if` to properly isolate each tab's view.
struct PreferencesView: View {
    @Bindable var viewModel: CaffeineViewModel
    let updater: UpdaterController

    enum Tab: String, CaseIterable, Identifiable {
        case general
        case about

        var id: String {
            self.rawValue
        }
    }

    @State private var selection: Tab = .general

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            Picker("", selection: self.$selection) {
                ForEach(Tab.allCases) { tab in
                    Text(self.title(for: tab)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Tab content - use if/else to properly isolate views
            if self.selection == .general {
                GeneralSettingsView(viewModel: self.viewModel)
            } else {
                AboutView(updater: self.updater)
            }
        }
        .frame(minWidth: 480, minHeight: 300)
    }

    private func title(for tab: Tab) -> String {
        switch tab {
        case .general:
            String(localized: "General", comment: "Settings tab title")
        case .about:
            String(localized: "About", comment: "Settings tab title")
        }
    }
}

#Preview {
    PreferencesView(viewModel: CaffeineViewModel(), updater: UpdaterController())
        .environment(\.locale, .init(identifier: "en"))
}
