//
//  HotkeyService.swift
//  Caffeine
//
//  Registers a single global hotkey via the Carbon
//  `RegisterEventHotKey` API. The registered hotkey can be
//  enabled/disabled at runtime and the callback invokes a
//  `@MainActor` closure on the main queue so the rest of the
//  app does not need to know about the Carbon internals.
//
//  Carbon's `RegisterEventHotKey` is preferred over
//  `NSEvent.addGlobalMonitorForEvents` because it does **not**
//  require Accessibility permission and works even when
//  Caffeine is not the frontmost app.

import Carbon.HIToolbox
import DZFoundation

/// Wraps a single Carbon `EventHotKeyRef` and its associated
/// `EventHandlerRef` so the two resources can be unregistered
/// and released together.
private final class HotkeyHandle {
    var hotKeyRef: EventHotKeyRef?
    var handlerRef: EventHandlerRef?

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }
}

/// Registers a single global hotkey via the Carbon API and
/// invokes `onTrigger` (on the main actor) each time the user
/// presses the registered combination.
///
/// `HotkeyService` is **not** observable — the caller observes
/// `SettingsModel` and calls `setEnabled(_:)` /
/// `updateHotkey(_:)` when the underlying settings change.
@MainActor
final class HotkeyService {
    // MARK: - Stored State

    private let handle = HotkeyHandle()
    private var onTrigger: (() -> Void)?

    /// Internal flag so `setEnabled` is a no-op when nothing
    /// has changed.
    private var registered: Bool = false

    // MARK: - Public API

    /// Installs the Carbon event handler that delivers the
    /// callback. Must be called exactly once at app start.
    func install(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
        self.installEventHandler()
    }

    /// Enables or disables the hotkey. The hotkey is only
    /// registered when both `enabled == true` and the stored
    /// `Hotkey` is non-empty.
    func setEnabled(_ enabled: Bool, hotkey: Hotkey) {
        if enabled, hotkey.isSet {
            self.register(hotkey: hotkey)
        } else {
            self.unregister()
        }
    }

    // MARK: - Registration

    private func installEventHandler() {
        let eventTypes = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            ),
        ]

        let userData = Unmanaged.passUnretained(self).toOpaque()

        let status = eventTypes.withUnsafeBufferPointer { eventTypesPtr -> OSStatus in
            InstallEventHandler(
                GetEventDispatcherTarget(),
                { _, eventRef, userData -> OSStatus in
                    guard let eventRef, let userData else { return noErr }
                    var hotKeyID = EventHotKeyID()
                    let copyStatus = GetEventParameter(
                        eventRef,
                        EventParamName(kEventParamDirectObject),
                        EventParamType(typeEventHotKeyID),
                        nil,
                        MemoryLayout<EventHotKeyID>.size,
                        nil,
                        &hotKeyID
                    )
                    guard copyStatus == noErr else { return copyStatus }

                    // The hotkey ID we registered with.
                    if hotKeyID.id == HotkeyService.hotKeyIDValue {
                        let service = Unmanaged<HotkeyService>
                            .fromOpaque(userData)
                            .takeUnretainedValue()
                        DispatchQueue.main.async {
                            service.onTrigger?()
                        }
                    }
                    return noErr
                },
                Int(eventTypes.count),
                eventTypesPtr.baseAddress,
                userData,
                &self.handle.handlerRef
            )
        }

        if status != noErr {
            DZErrorLog(
                NSError(
                    domain: "HotkeyService",
                    code: Int(status),
                    userInfo: [NSLocalizedDescriptionKey: "InstallEventHandler failed"]
                )
            )
        }
    }

    private func register(hotkey: Hotkey) {
        if self.registered {
            self.unregister()
        }
        guard hotkey.isSet else { return }

        let id = EventHotKeyID(
            signature: OSType(0x4341_4643), // 'CAFC' (Caffeine)
            id: HotkeyService.hotKeyIDValue
        )

        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers,
            id,
            GetEventDispatcherTarget(),
            0,
            &self.handle.hotKeyRef
        )

        if status == noErr {
            self.registered = true
            DZLog(
                "HotkeyService: registered keyCode=\(hotkey.keyCode) modifiers=\(hotkey.modifiers)"
            )
        } else {
            self.registered = false
            DZErrorLog(
                NSError(
                    domain: "HotkeyService",
                    code: Int(status),
                    userInfo: [NSLocalizedDescriptionKey: "RegisterEventHotKey failed"]
                )
            )
        }
    }

    private func unregister() {
        guard self.registered else { return }
        if let hotKeyRef = self.handle.hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.handle.hotKeyRef = nil
        }
        self.registered = false
        DZLog("HotkeyService: unregistered")
    }

    // MARK: - Constants

    /// The hotkey ID we use for our single registered hotkey.
    /// Any value distinct from the one used by other Carbon
    /// hotkey consumers is fine; we never compare against
    /// system-registered hotkeys.
    private static let hotKeyIDValue: UInt32 = 1
}
