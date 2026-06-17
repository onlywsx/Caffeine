//
//  PreferencesView.swift
//  Caffeine
//

import SwiftUI

/// Root of the Settings window. Hosts two tabs: General and About.
///
/// Uses a Picker(.segmented) for the tab bar so it follows the
/// system light/dark theme live. The macOS 15+ Tab initializer
/// caches its appearance at window creation in the Settings scene.
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

            // Tab content
            Group {
                switch self.selection {
                case .general:
                    GeneralSettingsView(viewModel: self.viewModel)
                case .about:
                    AboutView(updater: self.updater)
                }
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
