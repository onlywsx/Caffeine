//
//  PreferencesView.swift
//  Caffeine
//

import SwiftUI

/// Root of the Settings window. Hosts two tabs: General and About.
///
/// Uses the macOS 15+ Tab initializer. To work around the
/// segmented control caching its appearance at window creation,
/// observes `NSApp.effectiveAppearance` via KVO and forces the
/// TabView to recreate when the theme changes.
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

/// Observes `NSApp.effectiveAppearance` changes via KVO and
/// exposes the current appearance as a string. Used as a view
/// identity so SwiftUI recreates the TabView when the theme
/// changes.
@Observable
private final class AppearanceObserver {
    var effectiveAppearance: String = NSApp.effectiveAppearance.bestMatch(from: [
        .darkAqua,
        .aqua,
    ])?.rawValue ?? "unknown"

    private var observation: NSKeyValueObservation?

    init() {
        self.observation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] app, _ in
            let current = app.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])?.rawValue ?? "unknown"
            DispatchQueue.main.async {
                self?.effectiveAppearance = current
            }
        }
    }

    deinit {
        self.observation?.invalidate()
    }
}

#Preview {
    PreferencesView(viewModel: CaffeineViewModel(), updater: UpdaterController())
        .environment(\.locale, .init(identifier: "en"))
}
