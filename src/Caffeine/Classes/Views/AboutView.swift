//
//  AboutView.swift
//  Caffeine
//

import Sparkle
import SwiftUI

/// About tab. Read-only metadata about the app plus a Check for
/// Updates button. Layout matches the visual rhythm of the General
/// tab so the two sit well side-by-side in the Settings window.
struct AboutView: View {
    let updater: UpdaterController

    /// The bundle's marketing version (e.g. "1.6.5"). Read once at
    /// view init because the value is constant for the lifetime of
    /// the process.
    private let version: String = {
        if let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            return v
        }
        return "1.0.0"
    }()

    private let repoURL = URL(string: "https://github.com/dominc/Caffeine")!

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App icon + name + version + description
            HStack(alignment: .center, spacing: 16) {
                Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                    .resizable()
                    .frame(width: 140, height: 140)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Caffeine")
                        .font(.system(size: 20, weight: .semibold))

                    // Localized "Version %@"
                    Text(String(
                        format: String(localized: "Version %@", comment: "About tab version label"),
                        self.version
                    ))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                    Text(
                        "Caffeine keeps your Mac awake. Click the menu bar icon to disable automatic sleep; click it again to re-enable it."
                    )
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 24)

            // Credits (preserved from the old NSApp.orderFrontStandardAboutPanel credits)
            Text(
                "© 2006 Tomas Franzén\n© 2018 Michael Jones\n© 2022 Dominic Rodemer"
            )
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.bottom, 24)

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    NSWorkspace.shared.open(self.repoURL)
                } label: {
                    Text(String(localized: "View on GitHub", comment: "About tab: open repo in browser"))
                }

                Button {
                    self.updater.checkForUpdates()
                } label: {
                    Text(String(localized: "Check for Updates...", comment: "About tab: trigger Sparkle update check"))
                }
            }

            Spacer()
                .frame(height: 30)
        }
        .padding(.horizontal, 20)
        .frame(width: 640)
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    AboutView(updater: UpdaterController())
        .environment(\.locale, .init(identifier: "en"))
}
