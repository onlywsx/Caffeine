//
//  AppDelegate.swift
//  Caffeine
//
//  Created by Dominic Rodemer on 11.11.25.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        // Hide the dock icon - this is a menu bar only app
        NSApp.setActivationPolicy(.accessory)
    }
}
