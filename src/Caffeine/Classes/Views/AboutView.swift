//
//  AboutView.swift
//  Caffeine
//

import Sparkle
import SwiftUI

/// About tab. Read-only metadata about the app plus a Check for
/// Updates button.
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
        VStack(alignment: .leading, spacing: 12) {
            // App icon + name + version + description
            HStack(alignment: .center, spacing: 16) {
                Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                    .resizable()
                    .frame(width: 100, height: 100)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Caffeine")
                        .font(.system(size: 20, weight: .semibold))

                    Text(String(
                        format: String(localized: "Version %@", comment: "About tab version label"),
                        self.version
                    ))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                    Text("Caffeine keeps your Mac awake.")
                        .font(.system(size: 13))
                }
            }

            Spacer()

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
        }
        .padding()
    }
}

#Preview {
    AboutView(updater: UpdaterController())
        .environment(\.locale, .init(identifier: "en"))
}
