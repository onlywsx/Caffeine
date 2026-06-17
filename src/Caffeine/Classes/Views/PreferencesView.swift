//
//  PreferencesView.swift
//  Caffeine
//

import SwiftUI

/// Root of the Settings window. Hosts two tabs: General and About.
///
/// `CaffeineApp.swift` passes this view into the `Settings { }`
/// scene. The window's tab bar is rendered with a `Picker` using
/// `.segmented` style rather than SwiftUI's built-in `TabView`
/// segmented control. On macOS 14.6 the built-in `TabView`
/// segmented control caches its appearance at window creation
/// and does not re-resolve when the system theme changes; the app
/// has to be relaunched for the new theme to take effect. The
/// `Picker` segmented style is rebuilt by SwiftUI on
/// `colorScheme` change, so the tab bar follows the system theme
/// live.
struct PreferencesView: View {
    @Bindable var viewModel: CaffeineViewModel
    let updater: UpdaterController

    enum Tab: String, CaseIterable, Identifiable {
        case general
        case about

        var id: String {
            self.rawValue
        }

        var systemImage: String {
            switch self {
            case .general: "gearshape"
            case .about: "info.circle"
            }
        }
    }

    @State private var selection: Tab = .general

    var body: some View {
        VStack(spacing: 0) {
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

            Group {
                switch self.selection {
                case .general:
                    GeneralSettingsView(viewModel: self.viewModel)
                case .about:
                    AboutView(updater: self.updater)
                }
            }
        }
        .frame(minWidth: 680, minHeight: 520)
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
