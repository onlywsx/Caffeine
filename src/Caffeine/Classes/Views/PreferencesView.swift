//
//  PreferencesView.swift
//  Caffeine
//

import SwiftUI

/// Root of the Settings window. Hosts two tabs: General and About.
///
/// Uses the macOS 15+ Tab initializer. To work around the
/// segmented control caching its appearance at window creation,
/// observes `NSApp.effectiveAppearance` and forces the window to
/// re-evaluate on theme change.
struct PreferencesView: View {
    @Bindable var viewModel: CaffeineViewModel
    let updater: UpdaterController

    @State private var appearanceObserver = AppearanceObserver()

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
        .frame(minWidth: 480, minHeight: 300)
        .id(self.appearanceObserver.effectiveAppearance)
    }
}

/// Observes `NSApp.effectiveAppearance` changes and exposes the
/// current appearance as a string. Used as a view identity so
/// SwiftUI recreates the TabView when the theme changes.
@Observable
private final class AppearanceObserver {
    var effectiveAppearance: String = NSApp.effectiveAppearance.bestMatch(from: [
        .darkAqua,
        .aqua,
    ])?.rawValue ?? "unknown"

    init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.effectiveAppearance = NSApp.effectiveAppearance.bestMatch(from: [
                .darkAqua,
                .aqua,
            ])?.rawValue ?? "unknown"
        }
    }
}

#Preview {
    PreferencesView(viewModel: CaffeineViewModel(), updater: UpdaterController())
        .environment(\.locale, .init(identifier: "en"))
}
