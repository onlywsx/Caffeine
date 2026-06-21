//
//  PowerSourceMonitor.swift
//  Caffeine
//

import DZFoundation
import Foundation
import IOKit.ps

/// Observes changes to the system power source (AC connected,
/// battery, UPS) and battery charge level. Delivers callbacks on
/// the main queue so consumers can update UI or activate/deactivate
/// Caffeine without worrying about threading.
final class PowerSourceMonitor {
    /// Whether the system is currently on AC power.
    private(set) var isOnACPower: Bool

    /// The current battery charge percentage (0–100), or `nil`
    /// when no battery is present (e.g. a desktop Mac).
    private(set) var currentBatteryLevel: Int?

    /// Battery level threshold (percentage). When the battery
    /// drops from at-or-above this value to below it,
    /// `onBatteryBelowThreshold` fires once.
    var lowBatteryThreshold: Int = 20

    /// Called on the main queue when the power source type changes
    /// between AC power and battery/UPS. Passes `true` when the
    /// system is now on AC power, `false` otherwise.
    var onACPowerChanged: ((Bool) -> Void)?

    /// Called on the main queue once when the battery level drops
    /// below `lowBatteryThreshold`. Not re-fired until the battery
    /// rises back above the threshold and drops again.
    var onBatteryBelowThreshold: ((Int) -> Void)?

    private var runLoopSource: CFRunLoopSource?
    private var hasFiredLowBattery = false

    init() {
        self.isOnACPower = Self.checkIsOnACPower()
        self.currentBatteryLevel = Self.readBatteryLevel()
        self.hasFiredLowBattery = (self.currentBatteryLevel ?? 100)
            < self.lowBatteryThreshold
        self.startMonitoring()
    }

    deinit {
        self.stopMonitoring()
    }

    // MARK: - Private

    private func startMonitoring() {
        // `IOPSNotificationCreateRunLoopSource` accepts a C function
        // pointer (not a Swift closure), so we pass a module-level
        // trampoline that forwards the call to the shared instance.
        guard
            let unmanaged = IOPSNotificationCreateRunLoopSource(
                PowerSourceMonitorCallback,
                Unmanaged.passUnretained(self).toOpaque()
            ) else { return }
        let source = unmanaged.takeRetainedValue()
        self.runLoopSource = source
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            source,
            .defaultMode
        )
    }

    private func stopMonitoring() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                source,
                .defaultMode
            )
            self.runLoopSource = nil
        }
    }

    fileprivate func handlePowerSourceChange() {
        let nowOnAC = Self.checkIsOnACPower()
        if nowOnAC != self.isOnACPower {
            self.isOnACPower = nowOnAC
            DZLog("PowerSourceMonitor: AC power \(nowOnAC ? "connected" : "disconnected")")
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.onACPowerChanged?(self.isOnACPower)
            }
        }

        let newLevel = Self.readBatteryLevel()
        if newLevel != self.currentBatteryLevel {
            self.currentBatteryLevel = newLevel
            DZLog("PowerSourceMonitor: battery \(newLevel.map { "\($0)%" } ?? "n/a")")
        }

        if let level = newLevel {
            // Re-arm the one-shot guard when the battery charges
            // back above the threshold.
            if level >= self.lowBatteryThreshold {
                self.hasFiredLowBattery = false
            } else if !self.hasFiredLowBattery {
                self.hasFiredLowBattery = true
                DZLog("PowerSourceMonitor: battery below \(self.lowBatteryThreshold)%")
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.onBatteryBelowThreshold?(level)
                }
            }
        }
    }

    // MARK: - Snapshot Helpers

    /// Returns the current battery charge percentage (0–100), or
    /// `nil` when no internal battery is present.
    static func readBatteryLevel() -> Int? {
        guard let unmanagedInfo = IOPSCopyPowerSourcesInfo() else {
            return nil
        }
        let info: CFTypeRef = unmanagedInfo.takeRetainedValue()
        guard let unmanagedList = IOPSCopyPowerSourcesList(info) else {
            return nil
        }
        let list: CFArray = unmanagedList.takeRetainedValue() as CFArray
        let count = CFArrayGetCount(list)
        for i in 0..<count {
            // `CFArrayGetValueAtIndex` returns `UnsafeRawPointer?`.
            // The power-source handles are CFTypeRef (opaque
            // Core Foundation objects), not Swift objects, so we
            // must `unsafeBitCast` — `assumingMemoryBound` would
            // try to retain a raw pointer as an AnyObject and crash.
            guard let raw = CFArrayGetValueAtIndex(list, i) else {
                continue
            }
            let psRef: CFTypeRef = unsafeBitCast(raw, to: CFTypeRef.self)
            guard
                let unmanagedDesc = IOPSGetPowerSourceDescription(
                    info, psRef
                ) else { continue }
            let desc: CFDictionary = unmanagedDesc.takeUnretainedValue()
            guard let dict = desc as? [String: Any] else { continue }
            // Skip external batteries (UPS).
            if
                let type = dict[kIOPSTypeKey] as? String,
                type != kIOPSInternalBatteryType
            {
                continue
            }
            if let capacity = dict[kIOPSCurrentCapacityKey] as? Int {
                return capacity
            }
        }
        return nil
    }

    /// Snapshot check: returns `true` when the system's providing
    /// power source is AC.
    static func checkIsOnACPower() -> Bool {
        guard let unmanagedInfo = IOPSCopyPowerSourcesInfo() else {
            return false
        }
        let info: CFTypeRef = unmanagedInfo.takeRetainedValue()
        guard let unmanagedType = IOPSGetProvidingPowerSourceType(info) else {
            return false
        }
        let type = unmanagedType.takeUnretainedValue() as String
        return type == kIOPMACPowerKey
    }
}

/// C-function trampoline required by
/// `IOPSNotificationCreateRunLoopSource`. The `context` carries
/// the unretained `PowerSourceMonitor` pointer passed in
/// `startMonitoring()`.
private func PowerSourceMonitorCallback(context: UnsafeMutableRawPointer?) {
    guard let context else { return }
    let monitor = Unmanaged<PowerSourceMonitor>
        .fromOpaque(context)
        .takeUnretainedValue()
    monitor.handlePowerSourceChange()
}
