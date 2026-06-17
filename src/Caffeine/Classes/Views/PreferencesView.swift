//
//  PreferencesView.swift
//  Caffeine
//

import SwiftUI

/// Root of the Settings window. Hosts two tabs: General and About.
///
/// Uses the macOS 15+ Tab initializer. To work around the
/// segmented control caching its appearance at window creation,
/// observes `NSApp.effectiveAppearance` via KVO and forces
/// `NSApp.appearance` to update, which makes the segmented
/// control re-render in the new theme without rebuilding the
/// entire TabView.
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
        .onChange(of: self.appearanceObserver.effectiveAppearance) {
            // Force NSApp to use the new appearance, which causes
            // all segmented controls to re-render in the new theme.
            let name: NSAppearance.Name = self.appearanceObserver.effectiveAppearance == NSAppearance.Name.darkAqua
                .rawValue
                ? .darkAqua
                : .aqua
            NSApp.appearance = NSAppearance(named: name)
        }
    }
}

/// Observes `NSApp.effectiveAppearance` changes via KVO and
/// exposes the current appearance as a string.
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
            if self?.effectiveAppearance != current {
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
