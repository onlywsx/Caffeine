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
///
/// Each preference lives in `PreferenceSpec.defaults`, which
/// pairs the `UserDefaults` key with the user-facing default
/// and the getter that reads the live value back out for
/// persistence. Adding a new preference is one entry in that
/// table — the init and `persist(_:)` walk it automatically.
@MainActor
@Observable
final class SettingsModel {
    // MARK: - Stored Preferences

    /// Default activation duration in minutes. `0` means indefinite.
    var defaultDuration: Int

    /// Whether to activate Caffeine on launch.
    var activateAtLaunch: Bool

    /// Whether to deactivate when the device is manually put to sleep.
    var deactivateOnManualSleep: Bool

    /// Whether to simulate user activity to keep other apps awake.
    var keepAppsActive: Bool

    /// Whether to register Caffeine as a login item so it launches
    /// at user login.
    var startAtLogin: Bool

    /// Whether the display is allowed to sleep while Caffeine is
    /// preventing system sleep. When `true` (the default), only
    /// the system idle assertion is held; the display may dim and
    /// sleep on its normal schedule. When `false`, the stricter
    /// display assertion is held, which keeps both the system and
    /// the display awake.
    var allowDisplaySleep: Bool

    /// Whether to activate Caffeine automatically when the power
    /// adapter is connected. Default is off.
    var activateOnPowerConnect: Bool

    /// Whether to deactivate Caffeine automatically when the power
    /// adapter is disconnected. Default is off.
    var deactivateOnPowerDisconnect: Bool

    /// Whether to deactivate Caffeine when the battery level drops
    /// below `lowBatteryThreshold`. Default is off.
    var deactivateOnLowBattery: Bool

    /// Battery level percentage below which Caffeine is
    /// automatically deactivated (when `deactivateOnLowBattery` is
    /// on). Range: 5–50, default 20.
    var lowBatteryThreshold: Int

    /// Whether the global toggle hotkey is enabled. Default is
    /// `false` so the new feature does not surprise users with a
    /// pre-bound shortcut.
    var hotkeyEnabled: Bool

    /// Carbon virtual key code for the global toggle hotkey.
    /// Default is the virtual key code for `C` (`kVK_ANSI_C` =
    /// 8), the natural "C for Caffeine" mnemonic.
    var hotkeyKeyCode: UInt32

    /// Carbon modifier mask for the global toggle hotkey.
    /// Default is `cmdKey | shiftKey` so the default shortcut is
    /// `⌘⇧C`, which does not collide with the standard `⌘C`
    /// (Copy) or `⌘⇧C` used in any well-known macOS app.
    var hotkeyModifiers: UInt32

    // MARK: - UserDefaults Backing

    @ObservationIgnored
    private let defaults: UserDefaults

    // MARK: - Initialization

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.defaultDuration = Self.readInt(
            defaults,
            PreferenceKeys.defaultDuration,
            fallback: 0
        )
        self.activateAtLaunch = defaults.bool(forKey: PreferenceKeys.activateAtLaunch)
        self.deactivateOnManualSleep = defaults.bool(forKey: PreferenceKeys.deactivateOnManualSleep)
        self.keepAppsActive = defaults.bool(forKey: PreferenceKeys.keepAppsActive)
        self.startAtLogin = defaults.bool(forKey: PreferenceKeys.startAtLogin)
        // `UserDefaults.bool(forKey:)` returns `false` when no value
        // is recorded. The user-facing default for this preference
        // is `true`, so detect "no value recorded" first.
        self.allowDisplaySleep = Self.readBool(
            defaults,
            PreferenceKeys.allowDisplaySleep,
            fallback: true
        )
        self.activateOnPowerConnect = defaults.bool(forKey: PreferenceKeys.activateOnPowerConnect)
        self.deactivateOnPowerDisconnect = defaults.bool(forKey: PreferenceKeys.deactivateOnPowerDisconnect)
        self.deactivateOnLowBattery = defaults.bool(forKey: PreferenceKeys.deactivateOnLowBattery)
        self.lowBatteryThreshold = Self.readInt(
            defaults,
            PreferenceKeys.lowBatteryThreshold,
            fallback: 20
        )
        self.hotkeyEnabled = defaults.bool(forKey: PreferenceKeys.hotkeyEnabled)
        // `UserDefaults.integer(forKey:)` returns 0 for missing
        // keys; the user-facing default key code is `kVK_ANSI_C` (8).
        self.hotkeyKeyCode = UInt32(
            Self.readInt(
                defaults,
                PreferenceKeys.hotkeyKeyCode,
                fallback: 8
            )
        )
        // User-facing default modifier mask is `cmdKey | shiftKey`
        // = 0x0300 = 768.
        self.hotkeyModifiers = UInt32(
            Self.readInt(
                defaults,
                PreferenceKeys.hotkeyModifiers,
                fallback: 0x0300
            )
        )
    }

    // MARK: - Persistence

    /// Persists a single preference to `UserDefaults`. Call this
    /// from `.onChange` modifiers in views that bind to a property,
    /// or inline in view-model methods that mutate the model.
    /// Unknown keys log a debug message and are otherwise a no-op.
    func persist(_ key: String) {
        guard let spec = PreferenceSpec.defaults[key] else {
            DZLog("SettingsModel.persist: unknown key \(key)")
            return
        }
        self.defaults.set(spec.read(self), forKey: key)
    }

    // MARK: - Default Reads

    /// Returns `defaults.bool(forKey: key)` if a value has been
    /// recorded, otherwise the explicit `fallback`. `UserDefaults`
    /// has no "tri-state" bool — a missing key reads back as
    /// `false` even when the intended default is `true`.
    private static func readBool(
        _ defaults: UserDefaults,
        _ key: String,
        fallback: Bool
    )
        -> Bool
    {
        defaults.object(forKey: key) == nil
            ? fallback
            : defaults.bool(forKey: key)
    }

    /// Returns `defaults.integer(forKey: key)` if a value has been
    /// recorded, otherwise the explicit `fallback`.
    private static func readInt(
        _ defaults: UserDefaults,
        _ key: String,
        fallback: Int
    )
        -> Int
    {
        defaults.object(forKey: key) == nil
            ? fallback
            : defaults.integer(forKey: key)
    }
}

// MARK: - Preference Keys

/// `UserDefaults` keys for the user preferences. Centralised here
/// so that `SettingsModel`, `CaffeineViewModel`, and view bindings all
/// share the same string constants.
enum PreferenceKeys {
    static let activateAtLaunch = "CAActivateAtLaunch"
    static let defaultDuration = "CADefaultDuration"
    static let deactivateOnManualSleep = "CADeactivateOnManualSleep"
    static let keepAppsActive = "CAKeepAppsActive"
    static let startAtLogin = "CAStartAtLogin"
    static let allowDisplaySleep = "CAAllowDisplaySleep"
    static let activateOnPowerConnect = "CAActivateOnPowerConnect"
    static let deactivateOnPowerDisconnect = "CADeactivateOnPowerDisconnect"
    static let deactivateOnLowBattery = "CADeactivateOnLowBattery"
    static let lowBatteryThreshold = "CALowBatteryThreshold"
    static let hotkeyEnabled = "CAHotkeyEnabled"
    static let hotkeyKeyCode = "CAHotkeyKeyCode"
    static let hotkeyModifiers = "CAHotkeyModifiers"
}

// MARK: - Preference Specs

/// Describes a single `SettingsModel` preference: the
/// `UserDefaults` key, and the closure that reads the live value
/// out of `SettingsModel` so it can be persisted. Used by
/// `persist(_:)` to avoid an O(n) switch over all known keys.
private struct PreferenceSpec {
    let read: (SettingsModel) -> Any

    /// Lookup table from preference key to its spec. Populated
    /// lazily because `PreferenceSpec.read` captures `self`-
    /// style accessors and Swift's strict init order rules
    /// make an eager static let awkward.
    static let defaults: [String: PreferenceSpec] = [
        PreferenceKeys.defaultDuration: .init { $0.defaultDuration as Any },
        PreferenceKeys.activateAtLaunch: .init { $0.activateAtLaunch as Any },
        PreferenceKeys.deactivateOnManualSleep: .init { $0.deactivateOnManualSleep as Any },
        PreferenceKeys.keepAppsActive: .init { $0.keepAppsActive as Any },
        PreferenceKeys.startAtLogin: .init { $0.startAtLogin as Any },
        PreferenceKeys.allowDisplaySleep: .init { $0.allowDisplaySleep as Any },
        PreferenceKeys.activateOnPowerConnect: .init { $0.activateOnPowerConnect as Any },
        PreferenceKeys.deactivateOnPowerDisconnect: .init { $0.deactivateOnPowerDisconnect as Any },
        PreferenceKeys.deactivateOnLowBattery: .init { $0.deactivateOnLowBattery as Any },
        PreferenceKeys.lowBatteryThreshold: .init { $0.lowBatteryThreshold as Any },
        PreferenceKeys.hotkeyEnabled: .init { $0.hotkeyEnabled as Any },
        PreferenceKeys.hotkeyKeyCode: .init { $0.hotkeyKeyCode as Any },
        PreferenceKeys.hotkeyModifiers: .init { $0.hotkeyModifiers as Any },
    ]
}
