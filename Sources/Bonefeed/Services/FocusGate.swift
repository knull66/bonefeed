import Foundation
import Intents

/// Soft gate for macOS Focus / DND — market noise yields; ops alerts do not.
/// Requires `NSFocusStatusUsageDescription` in Info.plist (TCC kills the process otherwise).
@MainActor
enum FocusGate {
    private static var didRequestAuth = false

    /// Best-effort: true when system Focus appears active.
    static func isFocused() -> Bool {
        guard #available(macOS 12.0, *) else { return false }
        // Never touch Focus APIs without the usage string present (TCC abort).
        guard Bundle.main.object(forInfoDictionaryKey: "NSFocusStatusUsageDescription") != nil else {
            return false
        }

        let center = INFocusStatusCenter.default
        switch center.authorizationStatus {
        case .authorized:
            return center.focusStatus.isFocused == true
        case .notDetermined:
            if !didRequestAuth {
                didRequestAuth = true
                center.requestAuthorization { _ in }
            }
            return false
        default:
            return false
        }
    }
}
