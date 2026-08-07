import SwiftUI

/// Light motion helpers. Avoid animating MenuBarExtra root size/opacity —
/// that makes the panel open and instantly dismiss.
enum IslandMotion {
    static let snappy = Animation.easeOut(duration: 0.16)
    static let soft = Animation.easeInOut(duration: 0.22)
}
