//
//  GeneralSettingsView.swift
//  Caffeine
//

import SwiftUI

/// General preferences tab. Hosts the default activation duration,
/// launch behaviour, sleep behaviour, and the activity-simulation
/// toggle. Reads state directly from `UserDefaults` via
/// `@AppStorage` and routes the "keep apps active" toggle through
/// the view model so the `ActivitySimulator` can be
/// started/stopped.
struct GeneralSettingsView: View {
    @Bindable var viewModel: CaffeineViewModel
    @AppStorage(PreferenceKeys.defaultDuration) private var defaultDuration = 0
    @AppStorage(PreferenceKeys.activateAtLaunch) private var activateAtLaunch = false
    @AppStorage(PreferenceKeys.deactivateOnManualSleep) private var deactivateOnManualSleep = false
    @AppStorage(PreferenceKeys.keepAppsActive) private var keepAppsActive = false

    var body: some View {
        Form {
            Section {
                Picker("Default duration", selection: self.$defaultDuration) {
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                    Text("2 hours").tag(120)
                    Text("5 hours").tag(300)
                    Text("Indefinitely").tag(0)
                }
                .pickerStyle(.menu)
            }

            Section {
                Toggle("Activate when starting Caffeine", isOn: self.$activateAtLaunch)
                Toggle("Deactivate when device goes to sleep manually", isOn: self.$deactivateOnManualSleep)
            }

            Section {
                Toggle("Keep apps active", isOn: Binding(
                    get: { self.keepAppsActive },
                    set: { newValue in
                        self.keepAppsActive = newValue
                        self.viewModel.updateActivitySimulation(enabled: newValue)
                    }
                ))

                Text("Prevents apps from becoming inactive and the screen saver from starting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

#Preview {
    GeneralSettingsView(viewModel: CaffeineViewModel())
        .environment(\.locale, .init(identifier: "en"))
}
