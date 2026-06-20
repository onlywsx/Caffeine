//
//  GeneralSettingsView.swift
//  Caffeine
//

import SwiftUI

/// "General" tab of the Settings window. Bound to the shared
/// `SettingsModel`; persistence is triggered via `.onChange` for the
/// simple toggles and inline in the binding's `set` closure for the
/// `Keep apps active` toggle (which has a side effect on
/// `CaffeineViewModel`).
struct GeneralSettingsView: View {
    @Bindable var viewModel: CaffeineViewModel
    @Bindable var settings: SettingsModel

    var body: some View {
        Form {
            Section {
                Picker(
                    String(localized: "Default duration"),
                    selection: self.$settings.defaultDuration
                ) {
                    Text(String(localized: "5 minutes")).tag(5)
                    Text(String(localized: "10 minutes")).tag(10)
                    Text(String(localized: "15 minutes")).tag(15)
                    Text(String(localized: "30 minutes")).tag(30)
                    Text(String(localized: "1 hour")).tag(60)
                    Text(String(localized: "2 hours")).tag(120)
                    Text(String(localized: "5 hours")).tag(300)
                    Text(String(localized: "Indefinitely")).tag(0)
                }
                .pickerStyle(.menu)
            }

            Section {
                Toggle(
                    String(localized: "Activate when starting Caffeine"),
                    isOn: self.$settings.activateAtLaunch
                )
                Toggle(
                    String(localized: "Deactivate when device goes to sleep manually"),
                    isOn: self.$settings.deactivateOnManualSleep
                )
            }

            Section {
                Toggle(
                    String(localized: "Keep apps active"),
                    isOn: Binding(
                        get: { self.settings.keepAppsActive },
                        set: { newValue in
                            self.settings.keepAppsActive = newValue
                            self.settings.persist(PreferenceKeys.keepAppsActive)
                            self.viewModel.updateActivitySimulation(enabled: newValue)
                        }
                    )
                )

                Text(String(
                    localized: "Prevents apps from becoming inactive and the screen saver from starting.",
                    comment: "Help text for the Keep apps active toggle"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: self.settings.defaultDuration) { _, _ in
            self.settings.persist(PreferenceKeys.defaultDuration)
        }
        .onChange(of: self.settings.activateAtLaunch) { _, _ in
            self.settings.persist(PreferenceKeys.activateAtLaunch)
        }
        .onChange(of: self.settings.deactivateOnManualSleep) { _, _ in
            self.settings.persist(PreferenceKeys.deactivateOnManualSleep)
        }
    }
}

#Preview {
    GeneralSettingsView(
        viewModel: CaffeineViewModel(),
        settings: SettingsModel()
    )
    .environment(\.locale, .init(identifier: "en"))
}
