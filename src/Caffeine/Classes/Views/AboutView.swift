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
        VStack(alignment: .leading, spacing: 8) {
            // Version
            HStack(spacing: 4) {
                Text("Version")
                    .font(.system(size: 13))
                Text(self.version)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
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
        .frame(maxWidth: 520)
    }
}

#Preview {
    AboutView(updater: UpdaterController())
        .environment(\.locale, .init(identifier: "en"))
}
