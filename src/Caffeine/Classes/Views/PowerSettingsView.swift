//
//  PowerSettingsView.swift
//  Caffeine
//

import SwiftUI

/// "Power" tab of the Settings window. Contains display-sleep and
/// power-source related preferences. Bound to the shared
/// `SettingsModel`; persistence is triggered inline in each
/// custom binding's `set` closure.
struct PowerSettingsView: View {
    @Environment(CaffeineViewModel.self) private var viewModel: CaffeineViewModel
    @Environment(SettingsModel.self) private var settings: SettingsModel

    var body: some View {
        @Bindable var settings = self.settings
        @Bindable var viewModel = self.viewModel

        Form {
            Section {
                // Custom binding: side-effect on
                // `CaffeineViewModel.updateAllowDisplaySleep(enabled:)`
                // so the new assertion type takes effect immediately if
                // Caffeine is currently active.
                Toggle(
                    String(localized: "Allow display to sleep"),
                    isOn: Binding(
                        get: { self.settings.allowDisplaySleep },
                        set: { newValue in
                            self.settings.allowDisplaySleep = newValue
                            self.settings.persist(PreferenceKeys.allowDisplaySleep)
                            self.viewModel.updateAllowDisplaySleep(enabled: newValue)
                        }
                    )
                )

                Text(String(
                    localized: "Lets the display sleep on its normal schedule while keeping the Mac awake.",
                    comment: "Help text for the Allow display to sleep toggle"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                // Custom bindings: persist via the view-model's
                // dedicated methods so the `PowerSourceMonitor` is
                // lazily created on first enable.
                Toggle(
                    String(localized: "Activate when power adapter is connected"),
                    isOn: Binding(
                        get: { self.settings.activateOnPowerConnect },
                        set: { newValue in
                            self.settings.activateOnPowerConnect = newValue
                            self.settings.persist(PreferenceKeys.activateOnPowerConnect)
                            self.viewModel.updateActivateOnPowerConnect(enabled: newValue)
                        }
                    )
                )
                Toggle(
                    String(localized: "Deactivate when power adapter is disconnected"),
                    isOn: Binding(
                        get: { self.settings.deactivateOnPowerDisconnect },
                        set: { newValue in
                            self.settings.deactivateOnPowerDisconnect = newValue
                            self.settings.persist(PreferenceKeys.deactivateOnPowerDisconnect)
                            self.viewModel.updateDeactivateOnPowerDisconnect(enabled: newValue)
                        }
                    )
                )

                Text(String(
                    localized: "Automatically react when connecting or disconnecting the power adapter.",
                    comment: "Help text for the power adapter toggles"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                Toggle(
                    String(localized: "Deactivate on low battery"),
                    isOn: Binding(
                        get: { self.settings.deactivateOnLowBattery },
                        set: { newValue in
                            self.settings.deactivateOnLowBattery = newValue
                            self.settings.persist(PreferenceKeys.deactivateOnLowBattery)
                            self.viewModel.updateDeactivateOnLowBattery(
                                enabled: newValue
                            )
                        }
                    )
                )

                if self.settings.deactivateOnLowBattery {
                    HStack {
                        Text(String(
                            localized: "Threshold:",
                            comment: "Label before the low battery threshold percentage"
                        ))
                        Spacer()
                        Text(
                            "\(self.settings.lowBatteryThreshold)%"
                        )
                        .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { Double(self.settings.lowBatteryThreshold) },
                            set: { newValue in
                                let clamped = min(50, max(5, Int(newValue)))
                                self.settings.lowBatteryThreshold = clamped
                                self.settings.persist(PreferenceKeys.lowBatteryThreshold)
                                self.viewModel.updateLowBatteryThreshold(
                                    value: clamped
                                )
                            }
                        ),
                        in: 5...50,
                        step: 1
                    )
                }

                Text(String(
                    localized: "Automatically deactivate Caffeine when the battery level drops below the threshold.",
                    comment: "Help text for the Deactivate on low battery toggle"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    let settings = SettingsModel()
    return PowerSettingsView()
        .environment(CaffeineViewModel(settings: settings))
        .environment(settings)
        .environment(\.locale, .init(identifier: "en"))
}
