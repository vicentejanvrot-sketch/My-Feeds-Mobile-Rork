import SwiftUI

/// Run-status capsule: 1pt border in status color, 15% alpha background.
struct StatusPill: View {
    let status: RunStatus
    var showIcon = false

    var body: some View {
        HStack(spacing: 5) {
            if showIcon {
                Image(systemName: status.icon)
                    .font(.system(size: 12, weight: .semibold))
            }
            Text(status.label)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(status.color.opacity(0.15))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(status.color, lineWidth: 1))
    }
}

/// Item/channel watch-status capsule with a leading colored dot.
struct ChannelStatusPill: View {
    let status: ItemStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
            Text(status.actionLabel)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(status.color.opacity(0.15))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(status.color, lineWidth: 1))
    }
}
