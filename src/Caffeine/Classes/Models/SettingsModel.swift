//
//  SettingsModel.swift
//  Caffeine
//

import DZFoundation
import SwiftUI

/// Centralised, observable model for all user-facing preferences.
///
/// All reads/writes go through this type instead of scattering
/// `UserDefaults.standard.bool(forKey: ...)` calls across the
/// codebase. The `CaffeineViewModel` and the Settings tabs both
/// observe this single source of truth.
@MainActor
@Observable
final class SettingsModel {
    // MARK: - Stored Properties (mirror UserDefaults)

    /// Default activation duration in minutes. `0` means indefinite.
    /// Mirrors `PreferenceKeys.defaultDuration`.
    var defaultDuration: Int

    /// Whether to activate Caffeine on launch.
    /// Mirrors `PreferenceKeys.activateAtLaunch`.
    var activateAtLaunch: Bool

    /// Whether to deactivate when the device is manually put to sleep.
    /// Mirrors `PreferenceKeys.deactivateOnManualSleep`.
    var deactivateOnManualSleep: Bool

    /// Whether to simulate user activity to keep other apps awake.
    /// Mirrors `PreferenceKeys.keepAppsActive`.
    var keepAppsActive: Bool

    // MARK: - UserDefaults Backing

    @ObservationIgnored
    private let defaults: UserDefaults

    // MARK: - Initialization

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.defaultDuration = defaults.integer(forKey: PreferenceKeys.defaultDuration)
        self.activateAtLaunch = defaults.bool(forKey: PreferenceKeys.activateAtLaunch)
        self.deactivateOnManualSleep = defaults.bool(forKey: PreferenceKeys.deactivateOnManualSleep)
        self.keepAppsActive = defaults.bool(forKey: PreferenceKeys.keepAppsActive)
    }

    // MARK: - Persistence

    /// Persists a single value change to `UserDefaults`. Call this from
    /// `.onChange` modifiers in views that bind to a property, or
    /// inline in view-model methods that mutate the model.
    func persist(_ key: String) {
        let value: Any
        switch key {
        case PreferenceKeys.defaultDuration:
            value = self.defaultDuration
        case PreferenceKeys.activateAtLaunch:
            value = self.activateAtLaunch
        case PreferenceKeys.deactivateOnManualSleep:
            value = self.deactivateOnManualSleep
        case PreferenceKeys.keepAppsActive:
            value = self.keepAppsActive
        default:
            DZLog("SettingsModel.persist: unknown key \(key)")
            return
        }
        self.defaults.set(value, forKey: key)
    }
}

// MARK: - Preference Keys

/// `UserDefaults` keys for the four user preferences. Centralised here
/// so that `SettingsModel`, `CaffeineViewModel`, and view bindings all
/// share the same string constants.
enum PreferenceKeys {
    static let activateAtLaunch = "CAActivateAtLaunch"
    static let defaultDuration = "CADefaultDuration"
    static let deactivateOnManualSleep = "CADeactivateOnManualSleep"
    static let keepAppsActive = "CAKeepAppsActive"
}