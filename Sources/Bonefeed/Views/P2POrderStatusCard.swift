import SwiftUI

/// Binance-style live P2P order card — works for real C2C orders and local demos.
struct P2POrderStatusCard: View {
    let order: BinanceP2POrder
    var compact: Bool = false
    @Environment(\.chainPalette) private var p

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            headerRow
            Text(order.statusHeadline)
                .font(.system(size: compact ? 12 : 14, weight: .bold, design: .rounded))
                .foregroundStyle(p.text)
                .fixedSize(horizontal: false, vertical: true)
            stepper
            footerRow
        }
        .padding(compact ? 10 : 12)
        .background(
            RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous)
                .fill(p.panel.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous)
                .strokeBorder(p.strokeDim.opacity(0.85), lineWidth: 1)
        )
    }

    private var headerRow: some View {
        HStack(spacing: 6) {
            Text(order.tradeType.capitalized)
                .font(.system(size: compact ? 11 : 12, weight: .bold, design: .rounded))
                .foregroundStyle(order.tradeType == "SELL" ? p.danger : p.cool)
            Text(order.amountText)
                .font(.system(size: compact ? 11 : 12, weight: .semibold, design: .rounded))
                .foregroundStyle(p.text)
            Spacer(minLength: 4)
            Text("#\(order.shortOrderID)")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(p.muted)
                .lineLimit(1)
            if order.isSimulated {
                Text("DEMO")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(p.warn)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .overlay(Rectangle().stroke(p.warn.opacity(0.5), lineWidth: 1))
            }
        }
    }

    private var stepper: some View {
        let step = order.stepperIndex
        return HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { index in
                circleNode(active: step >= index, current: step == index, index: index)
                if index < 2 {
                    Rectangle()
                        .fill(step > index ? p.warn.opacity(0.85) : p.muted.opacity(0.25))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func circleNode(active: Bool, current: Bool, index: Int) -> some View {
        ZStack {
            Circle()
                .fill(active ? p.warn : p.bg.opacity(0.9))
                .frame(width: compact ? 18 : 22, height: compact ? 18 : 22)
            Circle()
                .strokeBorder(active ? p.warn : p.muted.opacity(0.35), lineWidth: 1)
                .frame(width: compact ? 18 : 22, height: compact ? 18 : 22)
            if current {
                Image(systemName: index == 0 ? "dollarsign" : (index == 1 ? "checkmark" : "arrow.up.right"))
                    .font(.system(size: compact ? 8 : 9, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.75))
            } else if active {
                Circle()
                    .fill(Color.black.opacity(0.35))
                    .frame(width: 5, height: 5)
            }
        }
    }

    private var footerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(order.fiatText.isEmpty ? order.fiat : order.fiatText)
                .font(.system(size: compact ? 13 : 16, weight: .bold, design: .rounded))
                .foregroundStyle(p.text)
            Spacer(minLength: 8)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = order.remainingSeconds(at: context.date)
                if let remaining, order.isOpen {
                    HStack(spacing: 4) {
                        Image(systemName: "stopwatch.fill")
                            .font(.system(size: compact ? 10 : 11, weight: .bold))
                        Text(Self.formatCountdown(remaining))
                            .font(.system(size: compact ? 12 : 14, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(remaining <= 60 ? p.danger : p.warn)
                } else if order.isOpen {
                    Text("LIVE")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(p.cool)
                } else {
                    Text(order.phase.shortLabel)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(p.muted)
                }
            }
        }
    }

    private static func formatCountdown(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }
}

// MARK: - Order presentation helpers

extension BinanceP2POrder {
    /// 0 = payment pending, 1 = paid, 2 = releasing / done path.
    var stepperIndex: Int {
        switch phase {
        case .pendingPayment, .other: 0
        case .paid: 1
        case .distributing, .completed: 2
        case .cancelled, .appeal: max(0, 1)
        }
    }

    var statusHeadline: String {
        switch phase {
        case .pendingPayment:
            tradeType == "BUY"
                ? L10n.t("p2p.card.paySeller")
                : L10n.t("p2p.card.waitBuyerPay")
        case .paid:
            tradeType == "SELL"
                ? L10n.t("p2p.card.releaseCrypto")
                : L10n.t("p2p.card.waitRelease")
        case .distributing:
            L10n.t("p2p.card.releasing")
        case .completed:
            L10n.t("p2p.card.done")
        case .cancelled:
            L10n.t("p2p.card.cancelled")
        case .appeal:
            L10n.t("p2p.card.appeal")
        case .other:
            L10n.t("p2p.card.update")
        }
    }

    func remainingSeconds(at date: Date = .now) -> Int? {
        guard isOpen, let expireTime else { return nil }
        return Int(expireTime.timeIntervalSince(date).rounded())
    }
}
