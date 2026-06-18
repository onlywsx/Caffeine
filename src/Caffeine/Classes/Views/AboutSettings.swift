//
//  AboutSettings.swift
//  Caffeine
//

import Sparkle
import SwiftUI

/// "About" tab. Read-only metadata about the app plus a Check for
/// Updates button. Uses `Form(.grouped)` to match the visual language
/// of `GeneralSettings`.
struct AboutSettings: View {
    let updater: UpdaterController

    private let version: String = {
        if let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            return v
        }
        return "1.0.0"
    }()

    private let repoURL = URL(string: "https://github.com/dominc/Caffeine")!

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                        .resizable()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    Text("Caffeine")
                        .font(.system(size: 18, weight: .semibold))

                    Text(String(
                        format: String(localized: "Version %@", comment: "About tab version label"),
                        self.version
                    ))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                    Text(String(localized: "Caffeine keeps your Mac awake."))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section {
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
        .formStyle(.grouped)
    }
}

#Preview {
    AboutSettings(updater: UpdaterController())
        .environment(\.locale, .init(identifier: "en"))
}
