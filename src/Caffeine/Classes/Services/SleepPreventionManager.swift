//
//  SleepPreventionManager.swift
//  Caffeine
//
//  Created by Dominic Rodemer on 11.11.25.
//

import Foundation
import IOKit.pwr_mgt

/// Holds the IOKit power-management assertion that prevents the
/// system (and optionally the display) from sleeping.
///
/// Owns no settings — the caller passes `allowDisplaySleep` per
/// call so the assertion always reflects the latest user
/// preference without this type duplicating state from
/// `SettingsModel`. Session-state gating is the caller's job:
/// when the user session is no longer active (fast user
/// switching, screen lock) the view model should call
/// `allowSleep()` first and `preventSleep(...)` again on resume.
@MainActor
final class SleepPreventionManager {
    private var sleepAssertionID: IOPMAssertionID?
    private var assertionTimer: Timer?

    deinit {
        // `Timer.invalidate()` is safe to call from any thread.
        // The held IOKit assertion is reclaimed by macOS at
        // process exit; this type's deinit only runs at app
        // shutdown, so the leak is bounded by the app's lifetime.
        self.assertionTimer?.invalidate()
    }

    /// Holds a system-wide sleep-prevention assertion. The
    /// assertion is refreshed every 10 seconds because macOS
    /// auto-releases assertions after 8 seconds.
    /// - Parameter allowDisplaySleep: `true` (default) holds the
    ///   system-only assertion so the display may dim and sleep
    ///   on its own schedule; `false` holds the stricter display
    ///   assertion that keeps the display awake as well.
    func preventSleep(allowDisplaySleep: Bool = true) {
        self.assertionTimer?.invalidate()
        self.assertionTimer = Timer.scheduledTimer(
            withTimeInterval: 10.0,
            repeats: true
        ) { [weak self] _ in
            // The timer fires on the run loop the timer was
            // scheduled on. Hop to the main actor (where the
            // IOKit call lives) and bind `self` to a local `let`
            // first so the `Task` body captures a constant
            // `Optional` rather than the mutable outer `self`.
            guard let self else { return }
            Task { @MainActor in
                self.refreshSleepAssertion(allowDisplaySleep: allowDisplaySleep)
            }
        }
        // Refresh once immediately so the user-visible effect
        // (no system sleep) kicks in without waiting for the
        // first tick.
        self.refreshSleepAssertion(allowDisplaySleep: allowDisplaySleep)
    }

    /// Releases the held assertion and stops refreshing.
    func allowSleep() {
        self.assertionTimer?.invalidate()
        self.assertionTimer = nil
        self.releaseSleepAssertion()
    }

    // MARK: - Private

    private func refreshSleepAssertion(allowDisplaySleep: Bool) {
        self.releaseSleepAssertion()

        // `kIOPMAssertPreventUserIdleSystemSleep` blocks only the
        // system from going idle — the display may still dim and
        // sleep. The stricter `kIOPMAssertPreventUserIdleDisplaySleep`
        // blocks both.
        let assertionType = allowDisplaySleep
            ? kIOPMAssertPreventUserIdleSystemSleep
            : kIOPMAssertPreventUserIdleDisplaySleep
        let reason = String(localized: "Caffeine prevents sleep") as CFString

        var assertionID: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithDescription(
            assertionType as CFString,
            reason,
            nil as CFString?,
            nil as CFString?,
            nil as CFString?,
            8, // Timeout after 8 seconds — refresh timer re-asserts every 10 s.
            nil as CFString?,
            &assertionID
        )

        if result == kIOReturnSuccess {
            self.sleepAssertionID = assertionID
        }
    }

    private func releaseSleepAssertion() {
        if let assertionID = self.sleepAssertionID {
            IOPMAssertionRelease(assertionID)
            self.sleepAssertionID = nil
        }
    }
}
