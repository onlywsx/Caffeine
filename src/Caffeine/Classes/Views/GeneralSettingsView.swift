//
//  GeneralSettingsView.swift
//  Caffeine
//

import SwiftUI

/// "General" tab of the Settings window. Contains core behaviour
/// preferences (duration, launch, login, activity). Power-related
/// settings live in `PowerSettingsView`.
struct GeneralSettingsView: View {
    @Environment(CaffeineViewModel.self) private var viewModel: CaffeineViewModel
    @Environment(SettingsModel.self) private var settings: SettingsModel

    var body: some View {
        @Bindable var settings = self.settings
        @Bindable var viewModel = self.viewModel

        Form {
            Section {
                Picker(
                    String(localized: "Default duration"),
                    selection: $settings.defaultDuration
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
                    isOn: $settings.activateAtLaunch
                )
                Toggle(
                    String(localized: "Deactivate when device goes to sleep manually"),
                    isOn: $settings.deactivateOnManualSleep
                )
            }

            Section {
                // Custom binding: side-effect on LoginItemService.setEnabled(_:) on
                // every change. The simple $settings.startAtLogin form would silently
                // skip the system call.
                Toggle(
                    String(localized: "Start at login"),
                    isOn: Binding(
                        get: { self.settings.startAtLogin },
                        set: { newValue in
                            self.settings.startAtLogin = newValue
                            self.settings.persist(PreferenceKeys.startAtLogin)
                            Task { await self.viewModel.applyLoginItemChange(newValue) }
                        }
                    )
                )

                if let message = self.viewModel.loginItemErrorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Text(String(
                    localized: "Automatically start Caffeine when you log in to your Mac.",
                    comment: "Help text for the Start at login toggle"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
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
    let settings = SettingsModel()
    let loginItem = LoginItemService(inMemoryWith: .disabled)
    return GeneralSettingsView()
        .environment(CaffeineViewModel(settings: settings, loginItem: loginItem))
        .environment(settings)
        .environment(\.locale, .init(identifier: "en"))
}
