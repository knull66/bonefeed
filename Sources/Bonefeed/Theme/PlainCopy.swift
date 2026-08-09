import Foundation

/// Short status codes shown in notch / header (cyber aesthetic).
enum RadarCode {
    static let boot = "BOOT"
    static let ok = "LISTENING"
    static let connected = "BINANCE"
    static let earn = "EARN"
    static let deposit = "DEPOSIT"
    static let incoming = "INCOMING"
    static let unlock = "UNLOCK"
    static let signal = "SIGNAL"
    static let health = "HEALTH"
    static let p2p = "P2P"
    static let error = "ERROR"

    static let calmCodes: Set<String> = [
        ok, connected, earn, "LISTENING", "BINANCE", "EARN", "OK"
    ]
}
