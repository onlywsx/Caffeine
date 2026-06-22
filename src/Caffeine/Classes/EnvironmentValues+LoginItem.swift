//
//  EnvironmentValues+LoginItem.swift
//  Caffeine
//

import SwiftUI

extension EnvironmentValues {
    /// `LoginItemService` provided by `CaffeineApp` to the General
    /// settings tab. Default is a live service backed by
    /// `SMAppService.mainApp` so views that don't explicitly inject
    /// one still operate against the real system — but production
    /// code in `CaffeineApp` always injects the shared instance.
    @Entry var loginItem: any LoginItemService = LiveLoginItemService()
}
