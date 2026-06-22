//
//  KeyboardSettingsView.swift
//  Caffeine
//
//  "Keyboard" tab of the Settings window. Lets the user enable
//  and configure the global hotkey that toggles Caffeine on/off
//  from anywhere on the system.
//
//  The hotkey is a `keyCode` + `modifiers` pair (the same shape
//  Carbon's `RegisterEventHotKey` consumes), stored in
//  `SettingsModel` and rendered back to the user as a glyph like
//  "⌘⇧C" via `Hotkey.displayString`.

import AppKit
import Carbon.HIToolbox
import DZFoundation
import SwiftUI

/// "Keyboard" tab of the Settings window. Contains the global
/// toggle hotkey preferences: an enable toggle, a recorder
/// button that captures the user's preferred key combination,
/// and a reset button that restores the default (`⌘⇧C`).
struct KeyboardSettingsView: View {
    @Environment(CaffeineViewModel.self) private var viewModel: CaffeineViewModel
    @Environment(SettingsModel.self) private var settings: SettingsModel

    /// `true` while the recorder button has focus and the next
    /// key press should be captured as the new hotkey.
    @State private var isRecording = false

    /// Bumps whenever a recording is in progress, so the
    /// `KeyboardShortcuts.Recorder` view redraws its "Press a
    /// key combination…" placeholder.
    @State private var recordingTick: Int = 0

    /// Monitors key events only while `isRecording == true`.
    @State private var localEventMonitor: Any?

    var body: some View {
        @Bindable var settings = self.settings
        @Bindable var viewModel = self.viewModel

        Form {
            Section {
                Toggle(
                    String(localized: "Enable global toggle shortcut"),
                    isOn: Binding(
                        get: { self.settings.hotkeyEnabled },
                        set: { newValue in
                            self.settings.hotkeyEnabled = newValue
                            self.settings.persist(PreferenceKeys.hotkeyEnabled)
                            self.viewModel.updateHotkeyEnabled(enabled: newValue)
                        }
                    )
                )

                Text(String(
                    localized: "Press the shortcut below from anywhere on your Mac to toggle Caffeine on or off.",
                    comment: "Help text for the global toggle shortcut"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Text(String(localized: "Shortcut:"))
                    Spacer()
                    self.recorderButton
                    Button(String(localized: "Reset")) {
                        self.resetToDefault()
                    }
                    .disabled(!self.settings.hotkeyEnabled)
                }

                Text(String(
                    localized: "Click the field and press a key combination. The shortcut will work even when Caffeine is not the active app.",
                    comment: "Help text for the shortcut recorder"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onDisappear {
            self.cancelRecording()
        }
    }

    // MARK: - Recorder Button

    private var recorderButton: some View {
        Button(action: self.toggleRecording) {
            // The frame and padding live on the ZStack so that
            // the hit-test region covers the entire rounded
            // rectangle, not just the text content.
            ZStack {
                Text(self.recorderLabel)
                    .font(.system(.body, design: .monospaced))
            }
            .frame(minWidth: 140, minHeight: 22)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color.secondary.opacity(0.4))
            )
            .contentShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .disabled(!self.settings.hotkeyEnabled)
        .id(self.recordingTick)
    }

    private var recorderLabel: String {
        if self.isRecording {
            return String(localized: "Press a key combination…")
        }
        let hotkey = Hotkey(
            keyCode: self.settings.hotkeyKeyCode,
            modifiers: self.settings.hotkeyModifiers
        )
        return hotkey.displayString
    }

    // MARK: - Recording

    private func toggleRecording() {
        if self.isRecording {
            self.cancelRecording()
        } else {
            self.beginRecording()
        }
    }

    private func beginRecording() {
        self.isRecording = true
        // `addLocalMonitorForEvents` blocks the event from the
        // rest of the app while we are recording. Returning the
        // event unchanged is fine — we just need to observe the
        // `keyDown`.
        self.localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .flagsChanged]
        ) { event in
            self.handle(event: event)
            return event
        }
    }

    private func cancelRecording() {
        if let monitor = self.localEventMonitor {
            NSEvent.removeMonitor(monitor)
            self.localEventMonitor = nil
        }
        self.isRecording = false
    }

    private func handle(event: NSEvent) {
        switch event.type {
        case .flagsChanged:
            // Modifier-only key presses are ignored — the
            // user must press a non-modifier key to complete
            // the recording. We still keep focus on the
            // button by not canceling.
            return

        case .keyDown:
            let keyCode = UInt32(event.keyCode)
            let modifiers = Hotkey.modifierMask(from: event.modifierFlags)

            // Allow Escape to cancel without binding a new shortcut.
            if keyCode == UInt32(kVK_Escape), modifiers == 0 {
                self.cancelRecording()
                return
            }

            // Reject pure modifier key codes (e.g. user pressed
            // just Cmd). These never produce useful bindings.
            if Self.isModifierOnly(keyCode: keyCode) {
                return
            }

            // Reject bindings with no modifiers — Cmd+0 alone
            // is too easy to fire accidentally and would
            // collide with normal typing.
            if modifiers == 0 {
                NSSound.beep()
                return
            }

            DZLog(
                "KeyboardSettingsView: captured keyCode=\(keyCode) modifiers=\(modifiers)"
            )
            // The view model and the view share a single
            // `SettingsModel`, so a single call updates the
            // stored value, persists it, and re-registers the
            // hotkey with the service.
            self.viewModel.updateHotkey(keyCode: keyCode, modifiers: modifiers)
            self.cancelRecording()

        default:
            return
        }
    }

    // MARK: - Helpers

    private func resetToDefault() {
        // Reset to the default ⌘⇧C. `updateHotkey` writes the
        // new value, persists it, and re-registers the service.
        self.viewModel.updateHotkey(keyCode: 8, modifiers: 0x0300)
        // Also exit record mode if the user was mid-recording
        // when they hit Reset — otherwise the field would
        // continue to show "Press a key combination…" even
        // though the binding has been restored.
        self.cancelRecording()
    }

    /// Returns `true` for the Carbon virtual key codes that
    /// represent modifier keys (Shift, Control, Option, Command,
    /// Caps Lock, Function). These should never be bound as the
    /// primary key of a hotkey.
    private static func isModifierOnly(keyCode: UInt32) -> Bool {
        switch keyCode {
        case UInt32(kVK_Shift),
             UInt32(kVK_RightShift),
             UInt32(kVK_Control),
             UInt32(kVK_RightControl),
             UInt32(kVK_Option),
             UInt32(kVK_RightOption),
             UInt32(kVK_Command),
             UInt32(kVK_RightCommand),
             UInt32(kVK_CapsLock),
             UInt32(kVK_Function):
            true
        default:
            false
        }
    }
}

#Preview {
    let settings = SettingsModel()
    return KeyboardSettingsView()
        .environment(CaffeineViewModel(settings: settings))
        .environment(settings)
        .environment(\.locale, .init(identifier: "en"))
}
