//
//  LoginItemService.swift
//  Caffeine
//

import DZFoundation
import Foundation
import ServiceManagement

/// Real-system status of the Caffeine login item.
enum LoginItemStatus: Equatable {
    /// Caffeine is registered as a login item.
    case enabled
    /// Caffeine is not registered.
    case disabled
    /// A previous registration attempt was denied; the user must
    /// approve Caffeine in System Settings → General → Login Items
    /// before the app can register itself.
    case requiresApproval
    /// System reported a status that does not map to the cases above
    /// (e.g. an SDK newer than this build expected).
    case unknown
}

/// Errors thrown by `LoginItemService.setEnabled(_:)`.
enum LoginItemError: LocalizedError {
    case underlying(String)
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .underlying:
            "Couldn't change login item setting."
        case .userCancelled:
            "Login item change was cancelled."
        }
    }
}

/// Wraps `SMAppService.mainApp` so views never depend on
/// `ServiceManagement` directly.
///
/// Use the parameterless `init()` in production — the service
/// queries `SMAppService.mainApp` on `refresh()` and on every
/// `setEnabled(_:)` call. Use `init(inMemoryWith:)` from
/// SwiftUI Previews and any future unit tests to construct a
/// deterministic instance that never touches the system.
@MainActor
@Observable
final class LoginItemService {
    /// Last known system status. Initial value is `.unknown` until
    /// `refresh()` completes at least once. In-memory instances
    /// (created via `init(inMemoryWith:)`) start with the supplied
    /// status and never call `refresh()` on their own.
    private(set) var status: LoginItemStatus

    /// `true` for instances created with `init(inMemoryWith:)`. The
    /// flag short-circuits all `ServiceManagement` calls so Previews
    /// don't trigger system side-effects.
    private let isInMemory: Bool

    /// Production initializer. Status starts at `.unknown` until
    /// `refresh()` is awaited.
    init() {
        self.status = .unknown
        self.isInMemory = false
    }

    /// In-memory initializer for SwiftUI Previews and tests. The
    /// supplied status is treated as the source of truth; `refresh()`
    /// is a no-op and `setEnabled(_:)` mutates `status` directly.
    init(inMemoryWith status: LoginItemStatus) {
        self.status = status
        self.isInMemory = true
    }

    /// Asks the system for the current login-item status and stores
    /// it in `status`. Safe to call multiple times. No-op for
    /// in-memory instances.
    func refresh() async {
        guard !self.isInMemory else { return }
        switch SMAppService.mainApp.status {
        case .enabled:
            self.status = .enabled
        case .requiresApproval:
            self.status = .requiresApproval
        case .notRegistered, .notFound:
            self.status = .disabled
        @unknown default:
            self.status = .unknown
        }
    }

    /// Requests that the system enable or disable Caffeine as a
    /// login item. On success, `status` reflects the new truth. On
    /// failure, throws `LoginItemError` and `status` is unchanged.
    func setEnabled(_ enabled: Bool) async throws {
        if self.isInMemory {
            self.status = enabled ? .enabled : .disabled
            return
        }
        do {
            if enabled {
                try await SMAppService.mainApp.register()
            } else {
                try await SMAppService.mainApp.unregister()
            }
        } catch is CancellationError {
            throw LoginItemError.userCancelled
        } catch {
            DZErrorLog(error)
            throw LoginItemError.underlying(error.localizedDescription)
        }
        await self.refresh()
    }
}
