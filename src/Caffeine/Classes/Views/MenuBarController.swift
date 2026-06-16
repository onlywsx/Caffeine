//
//  MenuBarController.swift
//  Caffeine
//
//  Created by Dominic Rodemer on 11.11.25.
//

import Cocoa
import Combine
import CoreGraphics
import DZFoundation
import Sparkle
import SwiftUI

@MainActor
class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var viewModel: CaffeineViewModel
    private var preferencesWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private let updaterController: SPUStandardUpdaterController
    /// Top-of-menu item that displays the time-remaining string while
    /// Caffeine is active. Updated in place as `viewModel.timeRemaining`
    /// changes, so we don't need to rebuild the menu on every tick.
    private weak var timeRemainingMenuItem: NSMenuItem?
    /// Mach port backing the `CGEventTap` that intercepts right-mouse
    /// events at the Core Graphics layer. On macOS 27,
    /// `NSStatusBarButton` (and any `statusItem.view`) no longer
    /// receives right-mouse events at the AppKit layer — neither via
    /// `sendAction(on:)`, subclassing, the "expanded interface"
    /// delegate, nor an `NSEvent` local monitor. Catching the event
    /// at the CG layer is the only path that works. Requires
    /// accessibility permission; invalidated in `cleanup()`.
    private var rightMouseEventTap: CFMachPort?
    /// Run loop source for `rightMouseEventTap`. Retained so we can
    /// remove it from the run loop in `cleanup()` and avoid leaking
    /// the source until process exit.
    private var rightMouseEventTapSource: CFRunLoopSource?
    /// `true` while a context menu is on screen. The `CGEventTap`
    /// callback uses this to decide whether to consume the
    /// right-click event (`return nil`) or pass it through to the
    /// menu's modal event loop so the loop can dismiss the current
    /// menu and the next right-click can replace it.
    private var isShowingContextMenu = false

    init(updaterController: SPUStandardUpdaterController) {
        self.updaterController = updaterController
        self.viewModel = CaffeineViewModel()
        super.init()
        self.setupMenuBar()
        self.setupObservers()

        // Ensure icon reflects the current state after full initialization
        // This is important because ViewModel.init() might activate if "activate at launch" is enabled
        self.updateIcon()
    }

    func cleanup() {
        self.viewModel.deactivate()
        if let tap = self.rightMouseEventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            self.rightMouseEventTap = nil
        }
        if let source = self.rightMouseEventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            self.rightMouseEventTapSource = nil
        }
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }

    deinit {
        // Safety net: if `cleanup()` was skipped (early return from
        // init, crash, test harness that drops the controller),
        // invalidate the tap before `self` is deallocated so the C
        // callback does not dereference a freed `userInfo` pointer.
        // The Mach port is also released when the run loop source
        // is dropped; we only need to make sure no further events
        // fire.
        if let tap = self.rightMouseEventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
    }

    private func setupMenuBar() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Use the default `NSStatusBarButton` so the active/inactive
        // image is rendered with the correct template-image
        // behaviour in both light and dark menu bars. Right-click is
        // not delivered to the button on macOS 27 — see
        // `installRightMouseEventTap()` for the Core-Graphics-level
        // workaround.
        guard let button = statusItem?.button else { return }
        button.action = #selector(self.statusItemClicked(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp])

        self.installRightMouseEventTap()
    }

    // MARK: - Right-mouse event tap (macOS 27 workaround)

    /// Install a session-level `CGEventTap` for right-mouse-down
    /// events. We filter to events that fall inside the status
    /// item's frame in screen coordinates; for those, we convert the
    /// `CGEvent` to an `NSEvent` and route it to `showContextMenu`.
    ///
    /// Requires accessibility permission ("System Settings → Privacy
    /// & Security → Accessibility"). If the tap cannot be created
    /// — typically because the user has not granted accessibility
    /// permission — we silently continue without right-click
    /// support.
    private func installRightMouseEventTap() {
        // Listen only for right-mouse-down. Real right-click on a
        // Magic Mouse or trackpad is delivered as `rightMouseDown`
        // at the CG layer; middle-click and other buttons arrive
        // as `otherMouseDown` with a different `buttonNumber` and
        // must be ignored — including them in the mask and filtering
        // by button inside the callback would still be a behaviour
        // change (middle-click on the status item would do nothing
        // visible, which is fine, but listening for up events too
        // is pure overhead since we never act on them).
        let eventMask: CGEventMask = (1 << CGEventType.rightMouseDown.rawValue)
        // Pass `self` as `userInfo` to the C callback. We use
        // `passUnretained` and rely on `deinit` (and `cleanup()`)
        // invalidating the tap before `self` is deallocated.
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { _, type, cgEvent, userInfo in
            guard
                let userInfo,
                type == .rightMouseDown else
            {
                return Unmanaged.passUnretained(cgEvent)
            }
            let controller = Unmanaged<MenuBarController>
                .fromOpaque(userInfo)
                .takeUnretainedValue()
            guard
                let statusItem = controller.statusItem,
                let button = statusItem.button,
                let window = button.window else
            {
                return Unmanaged.passUnretained(cgEvent)
            }
            // CGEvent.location uses a top-left origin (y grows
            // downward) while AppKit's `convertToScreen` returns
            // coordinates in the bottom-left system (y grows
            // upward). Flip `y` against the main screen height so
            // the two systems line up.
            let cgLoc = cgEvent.location
            guard let screenHeight = NSScreen.main?.frame.height else {
                return Unmanaged.passUnretained(cgEvent)
            }
            let appKitLocation = NSPoint(
                x: cgLoc.x,
                y: screenHeight - cgLoc.y
            )
            let frameInScreen = window.convertToScreen(button.convert(button.bounds, to: nil))
            guard frameInScreen.contains(appKitLocation) else {
                return Unmanaged.passUnretained(cgEvent)
            }
            guard let nsEvent = NSEvent(cgEvent: cgEvent) else {
                return Unmanaged.passUnretained(cgEvent)
            }
            // We are on the main thread (the tap is bound to the
            // main run loop), so this synchronous read/write of a
            // main-isolated property is safe. The flag is set
            // *synchronously here* — not inside the dispatched
            // Task — so a second right-click that lands while the
            // first popUp is running reliably sees `true` and
            // returns the event to the modal loop, instead of
            // racing with the Task that hasn't run yet.
            let menuAlreadyShowing = MainActor.assumeIsolated {
                if controller.isShowingContextMenu {
                    return true
                }
                controller.isShowingContextMenu = true
                return false
            }

            // Schedule the menu open on the main actor. We do NOT
            // call `popUp` synchronously from the tap callback:
            // doing so blocks the callback for as long as the menu
            // is on screen, and the OS will eventually disable the
            // event tap once it decides the callback is taking too
            // long. Dispatching to a `Task` lets the callback
            // return immediately, keeping the tap alive.
            //
            // If the user right-clicks again while a previous menu
            // is showing, the right-click is delivered to the
            // existing menu's modal event loop (which dismisses
            // it), the pending `Task` completes, and the next
            // scheduled `Task` then opens the new menu — giving the
            // natural "right-click-replaces-menu" behaviour.
            Task { @MainActor in
                controller.showContextMenu(for: nsEvent)
                controller.isShowingContextMenu = false
            }
            // If a menu is already on screen, return the event so
            // the menu's modal event loop can also see the
            // right-click and dismiss the current menu — the next
            // scheduled `Task` will then open the new menu. If no
            // menu is showing, consume the event (return nil) so
            // the system does not also process the right-click.
            if menuAlreadyShowing {
                return Unmanaged.passUnretained(cgEvent)
            } else {
                return nil
            }
        }

        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: eventMask,
                callback: callback,
                userInfo: userInfo
            ) else
        {
            // Accessibility permission is almost certainly missing.
            // Without it, right-click on the status item is a no-op.
            DZLog("Right-mouse event tap unavailable — accessibility permission is almost certainly missing.")
            return
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.rightMouseEventTap = tap
        self.rightMouseEventTapSource = runLoopSource
    }

    private func setupObservers() {
        self.viewModel.$isActive
            .sink { [weak self] _ in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.updateIcon()
                    self.updateTimeRemainingMenuItem()
                }
            }
            .store(in: &self.cancellables)

        // `timeRemaining` is published roughly once a second while
        // Caffeine is active. We keep the menu's top item in sync with
        // it so the user sees a live countdown when they right-click
        // the status item.
        self.viewModel.$timeRemaining
            .sink { [weak self] _ in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.updateTimeRemainingMenuItem()
                }
            }
            .store(in: &self.cancellables)

        self.viewModel.$showPreferences
            .sink { [weak self] show in
                if show {
                    self?.showPreferencesWindow()
                }
            }
            .store(in: &self.cancellables)
    }

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        let imageName = self.viewModel.isActive ? "active" : "inactive"
        if let image = NSImage(named: NSImage.Name(imageName)) {
            button.image = image
        }
    }

    @objc
    private func statusItemClicked(_: NSStatusBarButton) {
        // Control-left-click is the accessibility fallback for users
        // without a right mouse button. The right-mouse case is
        // handled by the `CGEventTap` in `installRightMouseEventTap()`
        // and never reaches this action selector on macOS 27.
        if
            let event = NSApp.currentEvent,
            event.type == .leftMouseUp,
            event.modifierFlags.contains(.control)
        {
            self.showContextMenu(for: event)
        } else {
            self.viewModel.toggleActive()
        }
    }

    /// Build the context menu shown on right-click. The second tuple
    /// element is the time-remaining item at the top of the menu, kept
    /// by the controller so it can be updated in place as the timer
    /// counts down (no menu rebuild on every tick).
    private func buildContextMenu() -> (NSMenu, NSMenuItem) {
        let menu = NSMenu()

        // Live time-remaining item (hidden when Caffeine is inactive).
        let timeItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        timeItem.isEnabled = false
        timeItem.isHidden = true
        menu.addItem(timeItem)
        menu.addItem(NSMenuItem.separator())

        // Duration options in submenu
        let activateForItem = NSMenuItem(
            title: String(localized: "Activate for"),
            action: nil,
            keyEquivalent: ""
        )
        let submenu = NSMenu()

        var durations: [(String, Int)] = [
            (String(localized: "Indefinitely"), 0),
            (String(localized: "5 minutes"), 5),
            (String(localized: "10 minutes"), 10),
            (String(localized: "15 minutes"), 15),
            (String(localized: "30 minutes"), 30),
            (String(localized: "1 hour"), 60),
            (String(localized: "2 hours"), 120),
            (String(localized: "5 hours"), 300),
        ]

        #if DEBUG
        durations.insert((String(localized: "1 minute"), 1), at: 1)
        #endif

        for (title, minutes) in durations {
            let item = NSMenuItem(
                title: title,
                action: #selector(activateWithDuration(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = minutes
            submenu.addItem(item)
        }

        activateForItem.submenu = submenu
        menu.addItem(activateForItem)

        menu.addItem(NSMenuItem.separator())

        // Preferences
        let prefsItem = NSMenuItem(
            title: String(localized: "Preferences..."),
            action: #selector(showPreferences(_:)),
            keyEquivalent: ","
        )
        prefsItem.target = self
        menu.addItem(prefsItem)

        // About
        let aboutItem = NSMenuItem(
            title: String(localized: "About Caffeine"),
            action: #selector(showAbout(_:)),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        // Update
        let updatesItem = NSMenuItem(
            title: String(localized: "Check for Updates..."),
            action: #selector(checkForUpdates(_:)),
            keyEquivalent: ""
        )
        updatesItem.target = self
        menu.addItem(updatesItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: String(localized: "Quit"),
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return (menu, timeItem)
    }

    /// Refresh the time-remaining menu item's title and visibility to
    /// reflect the current view-model state. Called whenever
    /// `isActive` or `timeRemaining` changes.
    private func updateTimeRemainingMenuItem() {
        guard let item = self.timeRemainingMenuItem else { return }
        if let title = self.viewModel.formattedTimeRemaining() {
            item.title = title
            item.isHidden = false
        } else {
            item.isHidden = true
        }
    }

    /// Pop up the context menu in response to a right-click (or a
    /// control-left-click accessibility fallback). On macOS 27,
    /// right-mouse events are intercepted by the `CGEventTap`
    /// installed in `installRightMouseEventTap()`; control-left-click
    /// reaches us via `statusItemClicked(_:)` instead.
    private func showContextMenu(for event: NSEvent) {
        guard
            let button = self.statusItem?.button,
            let window = button.window else
        {
            return
        }
        _ = event
        let (menu, timeItem) = self.buildContextMenu()
        self.timeRemainingMenuItem = timeItem
        self.updateTimeRemainingMenuItem()

        // Position the menu just below the status-bar button, in
        // screen coordinates. We do NOT rely on the event's
        // `locationInWindow`: when the event is synthesised from a
        // `CGEventTap` it has no associated window and the
        // location defaults to (0, 0), which would place the menu
        // at the top-left of the button's window — i.e. the
        // bottom-left corner of the screen. Computing the location
        // from the button's own frame avoids that problem.
        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        let buttonFrameInScreen = window.convertToScreen(buttonFrameInWindow)
        let menuLocation = NSPoint(
            x: buttonFrameInScreen.origin.x,
            y: buttonFrameInScreen.origin.y - 2
        )
        menu.popUp(positioning: nil, at: menuLocation, in: nil)
    }

    @objc
    private func activateWithDuration(_ sender: NSMenuItem) {
        let minutes = sender.tag
        let seconds = minutes > 0 ? TimeInterval(minutes * 60) : 0
        self.viewModel.activate(withTimeout: seconds)
    }

    @objc
    private func showPreferences(_: Any?) {
        self.showPreferencesWindow()
    }

    @objc
    private func checkForUpdates(_ sender: Any?) {
        self.updaterController.checkForUpdates(sender)
    }

    private func showPreferencesWindow() {
        NSApp.activate(ignoringOtherApps: true)

        if self.preferencesWindow == nil {
            let contentView = PreferencesView(viewModel: viewModel)
            let hostingController = NSHostingController(rootView: contentView)

            let window = NSWindow(contentViewController: hostingController)
            window.title = String(localized: "Welcome to Caffeine")
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 640, height: 420))
            window.center()

            self.preferencesWindow = window
        }

        self.preferencesWindow?.makeKeyAndOrderFront(nil)
    }

    @objc
    private func showAbout(_: Any?) {
        NSApp.activate(ignoringOtherApps: true)

        let credits =
            String(
                localized: "© 2006 Tomas Franzén\n© 2018 Michael Jones\n© 2022 Dominic Rodemer\n\nSource code:\nhttps://github.caffeine-app.net"
            )

        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(string: credits),
        ])
    }

    @objc
    private func quit(_: Any?) {
        NSApp.terminate(nil)
    }
}
