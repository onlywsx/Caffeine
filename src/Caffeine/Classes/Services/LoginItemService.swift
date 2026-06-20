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

/// Abstraction over the macOS login-item API so views never depend on
/// `SMAppService` directly. The live implementation is
/// `LiveLoginItemService`; the in-memory `FakeLoginItemService` is
/// used in tests (and as a placeholder until a test target exists).
@MainActor
protocol LoginItemService: AnyObject {
    /// Last known system status. Initial value is `.unknown` until
    /// `refresh()` completes at least once.
    var status: LoginItemStatus { get }

    /// Asks the system for the current login-item status and stores
    /// it in `status`. Safe to call multiple times.
    func refresh() async

    /// Requests that the system enable or disable Caffeine as a
    /// login item. On success, `status` reflects the new truth. On
    /// failure, throws `LoginItemError` and `status` is unchanged.
    func setEnabled(_ enabled: Bool) async throws
}

extension LoginItemService {
    /// Convenience factory for the live, system-backed implementation.
    static func live() -> any LoginItemService {
        LiveLoginItemService()
    }
}

/// In-memory `LoginItemService` for tests and for follow-up work that
/// needs a deterministic service without invoking `SMAppService`.
///
/// The optional `nextError` closure, when set, causes the next call
/// to `setEnabled(_:)` to throw the returned error and leaves `status`
/// unchanged. It is consumed (cleared) after one invocation, matching
/// the live behaviour where a failed register/unregister does not
/// retroactively mutate state.
@MainActor
final class FakeLoginItemService: LoginItemService {
    private(set) var status: LoginItemStatus = .disabled

    private var nextError: (@Sendable () -> LoginItemError)?

    init(initialStatus: LoginItemStatus = .disabled) {
        self.status = initialStatus
    }

    /// Inject a one-shot error to be thrown by the next
    /// `setEnabled(_:)` call. Pass `nil` to clear.
    func setNextError(_ factory: (@Sendable () -> LoginItemError)?) {
        self.nextError = factory
    }

    func refresh() async {
        // No-op: status already reflects the latest truth.
    }

    func setEnabled(_ enabled: Bool) async throws {
        if let factory = self.nextError {
            self.nextError = nil
            throw factory()
        }
        self.status = enabled ? .enabled : .disabled
    }
}

/// Live `LoginItemService` backed by `SMAppService.mainApp`.
@MainActor
final class LiveLoginItemService: LoginItemService {
    private let service = SMAppService.mainApp

    private(set) var status: LoginItemStatus = .unknown

    func refresh() async {
        switch self.service.status {
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

    func setEnabled(_ enabled: Bool) async throws {
        do {
            if enabled {
                try await self.service.register()
            } else {
                try await self.service.unregister()
            }
        } catch is CancellationError {
            throw LoginItemError.userCancelled
        } catch {
            DZErrorLog(error)
            throw LoginItemError.underlying(String(describing: error))
        }
        await self.refresh()
    }
}
