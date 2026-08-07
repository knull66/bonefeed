import SwiftUI

struct StatusDot: View {
    @Environment(\.chainPalette) private var p
    let status: IslandStatus

    var body: some View {
        Circle()
            .fill(p.statusColor(status))
            .frame(width: 7, height: 7)
            .shadow(color: p.statusColor(status).opacity(p.glow * 0.7), radius: status == .idle ? 0 : p.glow * 4)
            .accessibilityLabel(status.label)
    }
}
