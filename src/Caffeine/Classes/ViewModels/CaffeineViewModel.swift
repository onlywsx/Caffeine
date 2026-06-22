//
//  CaffeineViewModel.swift
//  Caffeine
//
//  Created by Dominic Rodemer on 11.11.25.
//

import ApplicationServices
import Combine
import DZFoundation
import SwiftUI

/// Main view model for the Caffeine application
@MainActor
@Observable
final class CaffeineViewModel {
    // MARK: - Published Properties

    var isActive = false
    var timeRemaining: TimeInterval?

    /// One-line message shown under the "Start at login" toggle
    /// when `LoginItemService.setEnabled(_:)` fails. `nil` while
    /// the toggle is healthy.
    private(set) var loginItemErrorMessage: String?

    // MARK: - Ignored (private) Properties

    @ObservationIgnored
    private let settings: SettingsModel

    @ObservationIgnored
    private var timeoutTimer: Timer?

    @ObservationIgnored
    private var displayTimer: Timer?

    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    @ObservationIgnored
    private var powerMonitor: PowerSourceMonitor?

    @ObservationIgnored
    private let hotkeyService = HotkeyService()

    @ObservationIgnored
    private let sleepPreventer: SleepPreventionManager

    @ObservationIgnored
    private let activitySimulator: ActivitySimulator

    @ObservationIgnored
    private let loginItem: LoginItemService

    @ObservationIgnored
    private var isUserSessionActive = true

    // MARK: - Initialization

    init(
        settings: SettingsModel,
        sleepPreventer: SleepPreventionManager? = nil,
        activitySimulator: ActivitySimulator? = nil,
        loginItem: LoginItemService? = nil
    ) {
        // Explicitly ensure we start inactive
        self.isActive = false
        self.timeRemaining = nil
        self.settings = settings

        // Lazy defaults: these `@MainActor` types cannot be
        // constructed from a non-isolated default-argument
        // context, so the init creates them itself.
        self.sleepPreventer = sleepPreventer ?? SleepPreventionManager()
        self.activitySimulator = activitySimulator ?? ActivitySimulator()
        self.loginItem = loginItem ?? LoginItemService()

        self.setupObservers()
        self.setupPowerMonitor()
        self.setupHotkey()

        // Sync the live login-item status with the system on launch
        // so the "Start at login" toggle reflects reality before
        // the user opens Settings.
        Task { await self.loginItem.refresh() }

        // Check if we should activate at launch
        if self.settings.activateAtLaunch {
            self.activate()
        }
    }

    // MARK: - Public Methods

    /// Toggles the active state
    func toggleActive() {
        if self.isActive {
            self.deactivate()
        } else {
            self.activate()
        }
    }

    /// Activates Caffeine with optional timeout
    func activate(withTimeout timeout: TimeInterval? = nil) {
        // Use default duration if no timeout specified
        let duration: TimeInterval?
        if let timeout {
            duration = timeout > 0 ? timeout : nil
        } else {
            let defaultMinutes = self.settings.defaultDuration
            duration = defaultMinutes > 0 ? TimeInterval(defaultMinutes * 60) : nil
        }

        // Cancel existing timers
        self.cancelTimers()

        // Set up timeout timer if duration specified
        if let duration {
            self.timeRemaining = duration

            self.timeoutTimer = Timer.scheduledTimer(
                withTimeInterval: duration,
                repeats: false
            ) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.deactivate()
                }
            }

            // Update display every second
            self.displayTimer = Timer.scheduledTimer(
                withTimeInterval: 1.0,
                repeats: true
            ) { [weak self] _ in
                DispatchQueue.main.async {
                    guard
                        let self,
                        let timeoutTimer = self.timeoutTimer else
                    {
                        self?.displayTimer?.invalidate()
                        return
                    }

                    self.timeRemaining = max(0, timeoutTimer.fireDate.timeIntervalSinceNow)
                    if self.timeRemaining ?? 0 <= 0 {
                        self.displayTimer?.invalidate()
                        self.displayTimer = nil
                    }
                }
            }
        } else {
            self.timeRemaining = nil
        }

        self.isActive = true
        self.sleepPreventer.preventSleep(
            allowDisplaySleep: self.settings.allowDisplaySleep
        )

        if self.settings.keepAppsActive {
            self.activitySimulator.startMonitoring()
        }
    }

    /// Deactivates Caffeine
    func deactivate() {
        self.cancelTimers()
        self.timeRemaining = nil
        self.isActive = false
        self.sleepPreventer.allowSleep()
        self.activitySimulator.stopMonitoring()
    }

    /// Updates activity simulation based on preference. Also keeps the
    /// `SettingsModel` and `UserDefaults` in sync with the new value.
    func updateActivitySimulation(enabled: Bool) {
        if self.settings.keepAppsActive != enabled {
            self.settings.keepAppsActive = enabled
            self.settings.persist(PreferenceKeys.keepAppsActive)
        }

        if enabled {
            // Trigger the Accessibility permission prompt by posting a no-op event
            // This prompts for "Events" permission which CGEvent.post requires
            self.activitySimulator.requestAccessibilityPermission()
        }

        if enabled, self.isActive {
            self.activitySimulator.startMonitoring()
        } else {
            self.activitySimulator.stopMonitoring()
        }
    }

    /// Updates the "allow display to sleep" preference. When active,
    /// re-applies the sleep assertion with the new flag so the change
    /// takes effect immediately rather than waiting for the next
    /// 10-second refresh tick.
    func updateAllowDisplaySleep(enabled: Bool) {
        if self.settings.allowDisplaySleep != enabled {
            self.settings.allowDisplaySleep = enabled
            self.settings.persist(PreferenceKeys.allowDisplaySleep)
        }

        if self.isActive {
            self.sleepPreventer.preventSleep(
                allowDisplaySleep: self.settings.allowDisplaySleep
            )
        }
    }

    /// Updates the "activate on power connect" preference. Persists
    /// the change; no immediate side-effect is needed — the monitor
    /// callback will read the new value on the next power event.
    func updateActivateOnPowerConnect(enabled: Bool) {
        if self.settings.activateOnPowerConnect != enabled {
            self.settings.activateOnPowerConnect = enabled
            self.settings.persist(PreferenceKeys.activateOnPowerConnect)
        }
        self.ensurePowerMonitorRunning()
    }

    /// Updates the "deactivate on power disconnect" preference.
    /// Persists the change; no immediate side-effect is needed.
    func updateDeactivateOnPowerDisconnect(enabled: Bool) {
        if self.settings.deactivateOnPowerDisconnect != enabled {
            self.settings.deactivateOnPowerDisconnect = enabled
            self.settings.persist(PreferenceKeys.deactivateOnPowerDisconnect)
        }
        self.ensurePowerMonitorRunning()
    }

    /// Updates the "deactivate on low battery" preference.
    /// Persists the change and ensures the power monitor is running.
    func updateDeactivateOnLowBattery(enabled: Bool) {
        if self.settings.deactivateOnLowBattery != enabled {
            self.settings.deactivateOnLowBattery = enabled
            self.settings.persist(PreferenceKeys.deactivateOnLowBattery)
        }
        self.ensurePowerMonitorRunning()
    }

    /// Updates the global toggle hotkey enabled flag. Persists
    /// the change and (re-)registers the hotkey with the
    /// underlying `HotkeyService`.
    func updateHotkeyEnabled(enabled: Bool) {
        if self.settings.hotkeyEnabled != enabled {
            self.settings.hotkeyEnabled = enabled
            self.settings.persist(PreferenceKeys.hotkeyEnabled)
        }
        self.applyHotkey()
    }

    /// Applies the user's "Start at login" toggle change to the
    /// underlying `LoginItemService`. On failure, reverts both
    /// the in-memory setting and the persisted preference, and
    /// surfaces a one-line error message under the toggle.
    func applyLoginItemChange(_ enabled: Bool) async {
        do {
            try await self.loginItem.setEnabled(enabled)
            self.loginItemErrorMessage = nil
        } catch {
            self.loginItemErrorMessage = error.localizedDescription
            self.settings.startAtLogin.toggle()
            self.settings.persist(PreferenceKeys.startAtLogin)
        }
    }

    /// Updates the global toggle hotkey key code and/or
    /// modifier mask. Persists both values and (re-)registers
    /// the hotkey with the underlying `HotkeyService`.
    func updateHotkey(keyCode: UInt32, modifiers: UInt32) {
        if self.settings.hotkeyKeyCode != keyCode {
            self.settings.hotkeyKeyCode = keyCode
            self.settings.persist(PreferenceKeys.hotkeyKeyCode)
        }
        if self.settings.hotkeyModifiers != modifiers {
            self.settings.hotkeyModifiers = modifiers
            self.settings.persist(PreferenceKeys.hotkeyModifiers)
        }
        self.applyHotkey()
    }

    /// Returns the currently configured hotkey, honouring
    /// `hotkeyEnabled`. The settings view binds to this.
    func currentHotkey() -> Hotkey {
        Hotkey(
            keyCode: self.settings.hotkeyKeyCode,
            modifiers: self.settings.hotkeyModifiers
        )
    }

    /// Updates the low battery threshold percentage. Persists the
    /// change and forwards the new value to the power monitor. If
    /// the battery is currently below the new threshold and Caffeine
    /// is active, deactivates immediately.
    func updateLowBatteryThreshold(value: Int) {
        if self.settings.lowBatteryThreshold != value {
            self.settings.lowBatteryThreshold = value
            self.settings.persist(PreferenceKeys.lowBatteryThreshold)
        }
        self.powerMonitor?.lowBatteryThreshold = value
        // Immediate check: if the battery is already below the new
        // threshold, deactivate now.
        if
            self.isActive, self.settings.deactivateOnLowBattery,
            let level = self.powerMonitor?.currentBatteryLevel,
            level < value
        {
            self.deactivate()
        }
    }

    /// Returns a formatted string for the remaining time
    func formattedTimeRemaining() -> String? {
        // Only return a status if actually active
        guard self.isActive else {
            return nil
        }

        // If there's time remaining, format it
        if let remaining = timeRemaining, remaining > 0 {
            let seconds = Int(remaining)

            if seconds >= 3600 {
                let hours = seconds / 3600
                let minutes = (seconds % 3600) / 60
                return String(format: "%02d:%02d", hours, minutes)
            } else if seconds > 60 {
                let minutes = seconds / 60
                let format = String(localized: "%d minutes", comment: "Time remaining in minutes")
                return String.localizedStringWithFormat(format, minutes)
            } else {
                let format = String(localized: "%d seconds", comment: "Time remaining in seconds")
                return String.localizedStringWithFormat(format, seconds)
            }
        }

        // Active with no timer (indefinite)
        return String(localized: "Caffeine is active")
    }

    // MARK: - Private Methods

    private func setupObservers() {
        // Observe workspace sleep notification
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    if self?.settings.deactivateOnManualSleep == true {
                        self?.deactivate()
                    }
                }
            }
            .store(in: &self.cancellables)

        // Run-loop timers don't advance during sleep, so on wake check whether
        // the activation period elapsed and deactivate if so
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let self, let timeoutTimer = self.timeoutTimer else { return }
                    if timeoutTimer.fireDate.timeIntervalSinceNow <= 0 {
                        self.deactivate()
                    }
                }
            }
            .store(in: &self.cancellables)

        // Fast user switching / screen lock. While the session
        // is inactive, the sleep-prevention assertion leaks
        // resources if we keep refreshing — release it on
        // resign and re-establish on resume.
        NSWorkspace.shared.notificationCenter.publisher(
            for: NSWorkspace.sessionDidResignActiveNotification
        )
        .sink { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isUserSessionActive = false
                if self.isActive {
                    self.sleepPreventer.allowSleep()
                }
            }
        }
        .store(in: &self.cancellables)

        NSWorkspace.shared.notificationCenter.publisher(
            for: NSWorkspace.sessionDidBecomeActiveNotification
        )
        .sink { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isUserSessionActive = true
                if self.isActive {
                    self.sleepPreventer.preventSleep(
                        allowDisplaySleep: self.settings.allowDisplaySleep
                    )
                }
            }
        }
        .store(in: &self.cancellables)
    }

    private func setupPowerMonitor() {
        self.ensurePowerMonitorRunning()
    }

    /// Installs the global hotkey trigger. The closure is
    /// `[weak self]` so the service never retains the view
    /// model past deinit.
    private func setupHotkey() {
        self.hotkeyService.install { [weak self] in
            self?.toggleActive()
        }
        self.applyHotkey()
    }

    /// Pushes the current `SettingsModel` hotkey state to the
    /// underlying `HotkeyService`.
    private func applyHotkey() {
        let hotkey = Hotkey(
            keyCode: self.settings.hotkeyKeyCode,
            modifiers: self.settings.hotkeyModifiers
        )
        self.hotkeyService.setEnabled(self.settings.hotkeyEnabled, hotkey: hotkey)
    }

    /// Lazily creates the `PowerSourceMonitor` if any power/battery
    /// preference is enabled and the monitor doesn't already exist.
    /// Does nothing if the monitor is already running or no relevant
    /// preference is enabled.
    private func ensurePowerMonitorRunning() {
        guard self.powerMonitor == nil else {
            // Monitor already running — just sync the threshold in
            // case the setting changed while it was already up.
            self.powerMonitor?.lowBatteryThreshold =
                self.settings.lowBatteryThreshold
            return
        }
        guard
            self.settings.activateOnPowerConnect
            || self.settings.deactivateOnPowerDisconnect
            || self.settings.deactivateOnLowBattery else
        {
            return
        }

        self.powerMonitor = PowerSourceMonitor()
        self.powerMonitor?.lowBatteryThreshold =
            self.settings.lowBatteryThreshold

        self.powerMonitor?.onACPowerChanged = { [weak self] isOnAC in
            guard let self else { return }
            if isOnAC, self.settings.activateOnPowerConnect {
                self.activate()
            } else if !isOnAC, self.settings.deactivateOnPowerDisconnect {
                self.deactivate()
            }
        }

        self.powerMonitor?.onBatteryBelowThreshold = { [weak self] _ in
            guard let self, self.settings.deactivateOnLowBattery else {
                return
            }
            DZLog("CaffeineViewModel: battery below threshold, deactivating")
            self.deactivate()
        }
    }

    private func cancelTimers() {
        self.timeoutTimer?.invalidate()
        self.timeoutTimer = nil
        self.displayTimer?.invalidate()
        self.displayTimer = nil
    }
}
