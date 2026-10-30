import Foundation
import LocalAuthentication

/// Face ID (or Touch ID / passcode) lock from onboarding screen 08 and Settings › Privacy.
@MainActor
final class AppLock: ObservableObject {
    /// True while the journal is covered and waiting for authentication.
    @Published private(set) var isLocked = false
    @Published private(set) var isAuthenticating = false

    enum Biometry {
        case faceID, touchID, opticID, none

        /// "Face ID", "Touch ID"… or "Passcode" on devices without biometrics.
        var name: String {
            switch self {
            case .faceID: return "Face ID"
            case .touchID: return "Touch ID"
            case .opticID: return "Optic ID"
            case .none: return "Passcode"
            }
        }
    }

    static var biometry: Biometry {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return .none
        }
    }

    /// Authenticates with biometrics, falling back to the device passcode. Used both to
    /// turn the lock on (so it can't be enabled on a device that can't satisfy it) and to
    /// unlock.
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return false }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }

    func lock() { isLocked = true }

    func unlock() {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        Task {
            let ok = await Self.authenticate(reason: "Unlock your journal")
            isAuthenticating = false
            if ok { isLocked = false }
        }
    }

    /// Turning the setting off from inside the app needs no prompt.
    func clear() { isLocked = false }
}
