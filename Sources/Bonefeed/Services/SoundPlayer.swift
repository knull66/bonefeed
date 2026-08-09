import AppKit
import Foundation

enum SoundPlayer {
    static func play(for kind: IslandAlert.Kind) {
        let name: String = switch kind {
        case .gas: "Tink"
        case .health: "Sosumi"
        case .pnl: "Funk"
        case .whale: "Purr"
        case .deposit: "Glass"
        case .earn: "Hero"
        case .p2p: "Glass"
        }

        if let sound = NSSound(named: name) {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    static func playTest() {
        if let sound = NSSound(named: "Ping") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }
}
