import SwiftUI

/// Shared visual steps used by first-run overlay and Settings → Guide.
struct GuideStepsView: View {
    let store: AppStore
    private var p: ThemePalette { store.palette }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            step("01", "BINANCE", store.t("guide.step1.body"), "key.fill")
            step("02", "NOTCH", store.t("guide.step2.body"), "menubar.rectangle")
            step("03", "LOG", store.t("guide.step3.body"), "bell.fill")
        }
    }

    private func step(_ code: String, _ title: String, _ body: String, _ symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(p.accent)
                    .frame(width: 40, height: 40)
                VStack(spacing: 1) {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .bold))
                    Text(code)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(p.bg)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(IslandTheme.monoBold)
                    .foregroundStyle(p.text)
                Text(body)
                    .font(IslandTheme.monoSmall)
                    .foregroundStyle(p.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(p.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(p.stroke, lineWidth: 1)
        )
    }
}

/// First-launch tutorial — cyber chrome. Also reopenable from Settings → Guide.
struct OnboardingGuideView: View {
    @Bindable var store: AppStore
    private var p: ThemePalette { store.palette }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    if let logo = AppLogoImage.load() {
                        Image(nsImage: logo)
                            .resizable()
                            .interpolation(.none)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(p.accent.opacity(0.45), lineWidth: 1)
                            )
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.t("onboard.title"))
                            .font(IslandTheme.monoTitle)
                            .foregroundStyle(p.accent)
                        Text(Brand.tagline)
                            .font(IslandTheme.monoSmall)
                            .foregroundStyle(p.muted)
                    }
                }

                Text(store.t("guide.blurb"))
                    .font(IslandTheme.monoSmall)
                    .foregroundStyle(p.muted)
                    .fixedSize(horizontal: false, vertical: true)

                GuideStepsView(store: store)

                Text("// \(store.t("guide.footnote"))")
                    .font(IslandTheme.monoSmall)
                    .foregroundStyle(p.muted)

                HStack {
                    Button(store.t("onboard.settings")) {
                        store.openAppSettings()
                    }
                    .buttonStyle(.plain)
                    .font(IslandTheme.monoBold)
                    .foregroundStyle(p.cool)

                    Spacer()

                    Button(store.t("onboard.ack")) {
                        store.completeOnboarding()
                    }
                    .buttonStyle(.plain)
                    .font(IslandTheme.monoBold)
                    .foregroundStyle(p.accent)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(p.panel.opacity(0.96))
    }
}
