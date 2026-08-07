import AppKit
import SwiftUI

/// Boot splash for the menu-bar panel. Fixed size only — never animate the window frame.
struct IslandSplashView: View {
    @Environment(\.chainPalette) private var p
    var onFinished: () -> Void

    @State private var logoVisible = false
    @State private var titleVisible = false
    @State private var barProgress: CGFloat = 0
    @State private var leaving = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [p.bg, p.bgMid, p.bg],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Soft radial glow behind logo (no window-size animation).
            Circle()
                .fill(p.accent.opacity(0.12))
                .frame(width: 180, height: 180)
                .blur(radius: 28)
                .allowsHitTesting(false)

            VStack(spacing: 18) {
                Group {
                    if let logo = AppLogoImage.load() {
                        Image(nsImage: logo)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [p.accent.opacity(0.85), p.cool.opacity(0.65)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                    } else {
                        Text("◈")
                            .font(.system(size: 56, weight: .bold, design: .monospaced))
                            .foregroundStyle(p.accent)
                    }
                }
                .scaleEffect(logoVisible ? 1 : 0.86)
                .opacity(logoVisible ? 1 : 0)

                VStack(spacing: 6) {
                    Text(Brand.nameUpper)
                        .font(IslandTheme.monoTitle)
                        .foregroundStyle(p.accent)
                        .tracking(3)
                    Text("BOOT SEQUENCE")
                        .font(IslandTheme.monoSmall)
                        .foregroundStyle(p.cool.opacity(0.85))
                        .tracking(0.5)
                }
                .opacity(titleVisible ? 1 : 0)
                .offset(y: titleVisible ? 0 : 6)

                // Fixed-height bar so layout never jumps.
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(p.strokeDim)
                        .frame(width: 160, height: 4)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [p.accent, p.cool],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 160 * barProgress, height: 4)
                }
                .opacity(titleVisible ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(leaving ? 0 : 1)
        .allowsHitTesting(!leaving)
        .onAppear { runBoot() }
    }

    private func runBoot() {
        withAnimation(.easeOut(duration: 0.28)) {
            logoVisible = true
        }
        withAnimation(.easeOut(duration: 0.32).delay(0.12)) {
            titleVisible = true
        }
        withAnimation(.easeInOut(duration: 0.85).delay(0.18)) {
            barProgress = 1
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1100))
            withAnimation(.easeOut(duration: 0.28)) {
                leaving = true
            }
            try? await Task.sleep(for: .milliseconds(280))
            onFinished()
        }
    }
}

enum AppLogoImage {
    @MainActor
    static func load() -> NSImage? {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        return NSApp.applicationIconImage
    }
}
