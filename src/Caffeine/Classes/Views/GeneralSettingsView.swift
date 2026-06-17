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
        VStack(alignment: .leading, spacing: 16) {
            // Default duration
            HStack(spacing: 8) {
                Text("Default duration:")
                    .font(.system(size: 13))
                    .frame(width: 120, alignment: .trailing)

                Picker("", selection: self.$defaultDuration) {
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
                .labelsHidden()
                .frame(width: 180, alignment: .leading)

                Spacer()
            }

            Divider()

            // Toggles
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Activate when starting Caffeine", isOn: self.$activateAtLaunch)
                    .font(.system(size: 13))

                Toggle("Deactivate when device goes to sleep manually", isOn: self.$deactivateOnManualSleep)
                    .font(.system(size: 13))

                Divider()

                Toggle("Keep apps active", isOn: Binding(
                    get: { self.keepAppsActive },
                    set: { newValue in
                        self.keepAppsActive = newValue
                        self.viewModel.updateActivitySimulation(enabled: newValue)
                    }
                ))
                .font(.system(size: 13))

                Text("Prevents apps from becoming inactive and the screen saver from starting.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    GeneralSettingsView(viewModel: CaffeineViewModel())
        .environment(\.locale, .init(identifier: "en"))
}
