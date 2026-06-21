//
//  ActivitySimulator.swift
//  Caffeine
//
//  Created by Dominic Rodemer on 14.12.24.
//

import AppKit
import CoreGraphics
import Foundation
import IOKit

/// Watches the system idle time and posts a `mouseMoved` HID
/// event when the user has been idle longer than
/// `idleThreshold`. Useful for keeping chat apps (Microsoft
/// Teams, Slack, …) from flipping to "Away" while Caffeine is
/// active.
///
/// Posting a `CGEvent` also prompts the user to grant the
/// Accessibility permission Caffeine needs to synthesise HID
/// events; the prompt is a one-time side-effect of the first
/// successful post.
@MainActor
final class ActivitySimulator {
    /// How long the user must be idle (seconds) before we
    /// synthesise activity.
    private let idleThreshold: TimeInterval = 90

    /// How often we poll the idle timer (seconds).
    private let checkInterval: TimeInterval = 30

    private var checkTimer: Timer?

    deinit {
        // `Timer.invalidate()` is safe from any thread.
        self.checkTimer?.invalidate()
    }

    // MARK: - Public API

    /// Starts the polling loop. Safe to call multiple times;
    /// any in-flight timer is invalidated first.
    func startMonitoring() {
        self.stopMonitoring()
        self.checkTimer = Timer.scheduledTimer(
            withTimeInterval: self.checkInterval,
            repeats: true
        ) { [weak self] _ in
            // The timer callback fires on the run loop the
            // timer was scheduled on (the main run loop), but
            // the closure is not `@MainActor`-isolated by
            // default. Hop explicitly so `checkAndSimulateIfNeeded`
            // (which posts a `CGEvent`) runs on the main actor.
            // Re-binding `self` to a local `let` first satisfies
            // strict-concurrency: the `Task` body then captures a
            // constant `Sendable` `Optional` instead of a
            // mutable `self` reference.
            guard let self else { return }
            Task { @MainActor in
                self.checkAndSimulateIfNeeded()
            }
        }
    }

    /// Stops the polling loop and releases any pending timer.
    func stopMonitoring() {
        self.checkTimer?.invalidate()
        self.checkTimer = nil
    }

    /// Posts a single no-op mouse event. The first successful
    /// post triggers the Accessibility permission prompt that
    /// `CGEvent.post(tap:)` requires.
    func requestAccessibilityPermission() {
        self.postMouseMovedEvent()
    }

    // MARK: - Private

    private func checkAndSimulateIfNeeded() {
        guard self.systemIdleTime() >= self.idleThreshold else { return }
        self.postMouseMovedEvent()
    }

    private func systemIdleTime() -> TimeInterval {
        var iterator: io_iterator_t = 0

        guard
            IOServiceGetMatchingServices(
                kIOMainPortDefault,
                IOServiceMatching("IOHIDSystem"),
                &iterator
            ) == KERN_SUCCESS else { return 0 }

        defer { IOObjectRelease(iterator) }

        let entry = IOIteratorNext(iterator)
        guard entry != 0 else { return 0 }
        defer { IOObjectRelease(entry) }

        var unmanagedDict: Unmanaged<CFMutableDictionary>?
        guard
            IORegistryEntryCreateCFProperties(
                entry,
                &unmanagedDict,
                kCFAllocatorDefault,
                0
            ) == KERN_SUCCESS,
            let dict = unmanagedDict?.takeRetainedValue() as? [String: Any],
            let idleTime = dict["HIDIdleTime"] as? Int64 else { return 0 }

        // HIDIdleTime is in nanoseconds.
        return TimeInterval(idleTime) / 1_000_000_000
    }

    private func postMouseMovedEvent() {
        // NSEvent.mouseLocation uses bottom-left origin; CGEvent
        // expects top-left. Flip the y axis against the main
        // screen height.
        let currentPos = NSEvent.mouseLocation
        guard let screenHeight = NSScreen.main?.frame.height else { return }
        let cgPoint = CGPoint(x: currentPos.x, y: screenHeight - currentPos.y)

        // `CGEvent.post` resets the system idle timer; CGWarpMouseCursorPosition
        // bypasses HID and does not.
        guard
            let moveEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: .mouseMoved,
                mouseCursorPosition: cgPoint,
                mouseButton: .left
            ) else { return }
        moveEvent.post(tap: .cghidEventTap)
    }
}
