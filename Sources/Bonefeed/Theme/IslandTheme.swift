import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case cyberDark
    case cyberNeon
    case phosphor
    case noir
    case binance
    case macDark
    case macLight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cyberDark: "CYBER DIM"
        case .cyberNeon: "CYBER NEON"
        case .phosphor: "PHOSPHOR"
        case .noir: "NOIR"
        case .binance: "BINANCE"
        case .macDark: "MAC DARK"
        case .macLight: "MAC LIGHT"
        }
    }

    var blurb: String {
        switch self {
        case .cyberDark: "soft neon, less eye strain"
        case .cyberNeon: "strong magenta / cyan"
        case .phosphor: "green CRT terminal"
        case .noir: "near monochrome"
        case .binance: "Binance yellow & dark UI"
        case .macDark: "native macOS dark"
        case .macLight: "native macOS light"
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .macLight: .light
        default: .dark
        }
    }

    var isLight: Bool { self == .macLight }

    var requiresPro: Bool { !ProLimits.freeThemes.contains(self) }
}

struct ThemePalette: Equatable {
    let bg: Color
    let bgMid: Color
    let panel: Color
    let stroke: Color
    let strokeDim: Color
    let text: Color
    let muted: Color
    let accent: Color
    let cool: Color
    let warn: Color
    let danger: Color
    /// 0…1 — intensity of neon glow / grid
    let glow: Double
    let gridOpacity: Double
    let scanlineOpacity: Double

    func statusColor(_ status: IslandStatus) -> Color {
        switch status {
        case .idle: muted
        case .watching: cool
        case .alert: warn
        case .actionNeeded: accent
        case .error: danger
        }
    }

    func pnlColor(_ value: Double) -> Color {
        value >= 0 ? cool : danger
    }

    func feeColor(_ level: FeeSnapshot.FeeLevel) -> Color {
        switch level {
        case .low: cool
        case .normal: warn
        case .high: danger
        }
    }

    static func forTheme(_ theme: AppTheme) -> ThemePalette {
        switch theme {
        case .cyberDark:
            ThemePalette(
                bg: Color(red: 0.05, green: 0.04, blue: 0.07),
                bgMid: Color(red: 0.08, green: 0.05, blue: 0.11),
                panel: Color(red: 0.09, green: 0.07, blue: 0.12),
                stroke: Color(red: 0.72, green: 0.28, blue: 0.55).opacity(0.35),
                strokeDim: Color(red: 0.25, green: 0.55, blue: 0.65).opacity(0.22),
                text: Color(red: 0.82, green: 0.84, blue: 0.90),
                muted: Color(red: 0.42, green: 0.40, blue: 0.52),
                accent: Color(red: 0.78, green: 0.32, blue: 0.58),
                cool: Color(red: 0.28, green: 0.68, blue: 0.74),
                warn: Color(red: 0.82, green: 0.68, blue: 0.28),
                danger: Color(red: 0.82, green: 0.35, blue: 0.42),
                glow: 0.18,
                gridOpacity: 0.06,
                scanlineOpacity: 0.05
            )
        case .cyberNeon:
            ThemePalette(
                bg: Color(red: 0.04, green: 0.02, blue: 0.08),
                bgMid: Color(red: 0.10, green: 0.03, blue: 0.18),
                panel: Color(red: 0.08, green: 0.04, blue: 0.14),
                stroke: Color(red: 1.0, green: 0.18, blue: 0.65).opacity(0.55),
                strokeDim: Color(red: 0.0, green: 0.90, blue: 1.0).opacity(0.22),
                text: Color(red: 0.92, green: 0.95, blue: 1.0),
                muted: Color(red: 0.55, green: 0.48, blue: 0.72),
                accent: Color(red: 1.0, green: 0.20, blue: 0.72),
                cool: Color(red: 0.0, green: 0.95, blue: 1.0),
                warn: Color(red: 1.0, green: 0.92, blue: 0.15),
                danger: Color(red: 1.0, green: 0.28, blue: 0.42),
                glow: 0.55,
                gridOpacity: 0.18,
                scanlineOpacity: 0.10
            )
        case .phosphor:
            ThemePalette(
                bg: Color(red: 0.04, green: 0.05, blue: 0.04),
                bgMid: Color(red: 0.06, green: 0.08, blue: 0.06),
                panel: Color(red: 0.07, green: 0.09, blue: 0.07),
                stroke: Color(red: 0.25, green: 0.45, blue: 0.28).opacity(0.40),
                strokeDim: Color(red: 0.20, green: 0.35, blue: 0.22).opacity(0.30),
                text: Color(red: 0.72, green: 0.90, blue: 0.68),
                muted: Color(red: 0.35, green: 0.48, blue: 0.34),
                accent: Color(red: 0.40, green: 0.85, blue: 0.38),
                cool: Color(red: 0.45, green: 0.75, blue: 0.65),
                warn: Color(red: 0.85, green: 0.70, blue: 0.25),
                danger: Color(red: 0.85, green: 0.35, blue: 0.28),
                glow: 0.22,
                gridOpacity: 0.04,
                scanlineOpacity: 0.08
            )
        case .noir:
            ThemePalette(
                bg: Color(red: 0.04, green: 0.04, blue: 0.045),
                bgMid: Color(red: 0.07, green: 0.07, blue: 0.08),
                panel: Color(red: 0.08, green: 0.08, blue: 0.09),
                stroke: Color.white.opacity(0.12),
                strokeDim: Color.white.opacity(0.08),
                text: Color(red: 0.78, green: 0.78, blue: 0.80),
                muted: Color(red: 0.40, green: 0.40, blue: 0.43),
                accent: Color(red: 0.55, green: 0.62, blue: 0.70),
                cool: Color(red: 0.45, green: 0.58, blue: 0.62),
                warn: Color(red: 0.72, green: 0.62, blue: 0.40),
                danger: Color(red: 0.72, green: 0.42, blue: 0.42),
                glow: 0.08,
                gridOpacity: 0.03,
                scanlineOpacity: 0.04
            )
        case .binance:
            // Binance brand: yellow #F0B90B on near-black #0B0E11
            ThemePalette(
                bg: Color(red: 0.043, green: 0.055, blue: 0.067),
                bgMid: Color(red: 0.09, green: 0.10, blue: 0.12),
                panel: Color(red: 0.118, green: 0.125, blue: 0.149),
                stroke: Color(red: 0.941, green: 0.725, blue: 0.043).opacity(0.40),
                strokeDim: Color(red: 0.941, green: 0.725, blue: 0.043).opacity(0.18),
                text: Color(red: 0.918, green: 0.925, blue: 0.937),
                muted: Color(red: 0.518, green: 0.557, blue: 0.612),
                accent: Color(red: 0.941, green: 0.725, blue: 0.043),
                cool: Color(red: 0.055, green: 0.796, blue: 0.506),
                warn: Color(red: 0.941, green: 0.725, blue: 0.043),
                danger: Color(red: 0.965, green: 0.275, blue: 0.365),
                glow: 0.20,
                gridOpacity: 0.04,
                scanlineOpacity: 0.03
            )
        case .macDark:
            ThemePalette(
                bg: Color(red: 0.11, green: 0.11, blue: 0.118),
                bgMid: Color(red: 0.14, green: 0.14, blue: 0.15),
                panel: Color(red: 0.173, green: 0.173, blue: 0.180),
                stroke: Color.white.opacity(0.14),
                strokeDim: Color.white.opacity(0.08),
                text: Color(red: 0.92, green: 0.92, blue: 0.94),
                muted: Color(red: 0.557, green: 0.557, blue: 0.576),
                accent: Color(red: 0.039, green: 0.518, blue: 1.0),
                cool: Color(red: 0.188, green: 0.820, blue: 0.345),
                warn: Color(red: 1.0, green: 0.839, blue: 0.039),
                danger: Color(red: 1.0, green: 0.271, blue: 0.227),
                glow: 0.06,
                gridOpacity: 0.02,
                scanlineOpacity: 0.0
            )
        case .macLight:
            ThemePalette(
                bg: Color(red: 0.949, green: 0.949, blue: 0.969),
                bgMid: Color(red: 0.98, green: 0.98, blue: 0.985),
                panel: Color.white,
                stroke: Color.black.opacity(0.10),
                strokeDim: Color.black.opacity(0.06),
                text: Color(red: 0.11, green: 0.11, blue: 0.118),
                muted: Color(red: 0.557, green: 0.557, blue: 0.576),
                accent: Color(red: 0.0, green: 0.478, blue: 1.0),
                cool: Color(red: 0.204, green: 0.780, blue: 0.349),
                warn: Color(red: 1.0, green: 0.624, blue: 0.039),
                danger: Color(red: 1.0, green: 0.231, blue: 0.188),
                glow: 0.0,
                gridOpacity: 0.0,
                scanlineOpacity: 0.0
            )
        }
    }
}

enum IslandTheme {
    static let mono: Font = .system(size: 11, weight: .semibold, design: .monospaced)
    static let monoBold: Font = .system(size: 11, weight: .heavy, design: .monospaced)
    static let monoSmall: Font = .system(size: 10, weight: .semibold, design: .monospaced)
    static let monoTitle: Font = .system(size: 13, weight: .heavy, design: .monospaced)
    static let monoHero: Font = .system(size: 20, weight: .heavy, design: .monospaced)
}

// MARK: - Environment

private struct ChainPaletteKey: EnvironmentKey {
    static let defaultValue = ThemePalette.forTheme(.cyberDark)
}

extension EnvironmentValues {
    var chainPalette: ThemePalette {
        get { self[ChainPaletteKey.self] }
        set { self[ChainPaletteKey.self] = newValue }
    }
}
