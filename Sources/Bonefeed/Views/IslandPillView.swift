import SwiftUI

/// Keep this view light — MenuBarExtra labels break with heavy effects.
struct IslandPillView: View {
    let store: AppStore
    private var p: ThemePalette { store.palette }

    var body: some View {
        HStack(spacing: 5) {
            Text(store.pillPulse ? "◆" : "◇")
                .font(IslandTheme.monoBold)
                .foregroundStyle(p.statusColor(store.snapshot.status))

            Text(store.pillPulse ? "ALERT" : store.snapshot.radarLabel)
                .font(IslandTheme.monoBold)
                .foregroundStyle(store.pillPulse ? p.danger : p.accent)
                .tracking(1)

            Text("::")
                .font(IslandTheme.monoSmall)
                .foregroundStyle(p.cool.opacity(0.7))

            if let last = store.depositLog.first {
                Text("+\(last.asset)")
                    .font(IslandTheme.monoBold)
                    .foregroundStyle(p.warn)
            } else if store.snapshot.binanceConnected {
                Text(store.snapshot.binancePortfolioUSD.asUSDPill)
                    .font(IslandTheme.monoBold)
                    .foregroundStyle(p.cool)
            } else {
                Text(store.pillFeeText)
                    .font(IslandTheme.mono)
                    .foregroundStyle(p.feeColor(store.snapshot.fee.level))
            }

            if store.unreadAlertCount > 0 {
                Text("≪\(store.unreadAlertCount)≫")
                    .font(IslandTheme.monoBold)
                    .foregroundStyle(p.danger)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(p.bg.opacity(0.92))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [p.accent.opacity(0.7), p.cool.opacity(0.55)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .environment(\.chainPalette, p)
    }
}

private extension Double {
    var asUSDPill: String {
        abs(self) >= 1000
            ? String(format: "$%.1fk", self / 1000)
            : String(format: "$%.0f", self)
    }
}
