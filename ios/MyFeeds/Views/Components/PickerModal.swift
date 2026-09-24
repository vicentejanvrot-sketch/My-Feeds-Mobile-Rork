import SwiftUI

/// Centered picker modal used for feed filters and status selection —
/// matches the companion apps' dimmed centered sheets.
struct PickerModal<Content: View>: View {
    let title: String
    let onDismiss: () -> Void
    @ViewBuilder let content: Content

    @State private var contentHeight: CGFloat = 0
    private let maxListHeight: CGFloat = 340

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(alignment: .leading, spacing: 0) {
                Text(title.uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .kerning(0.5)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                // Measure the rows and give the ScrollView exactly that height
                // (capped at 340pt). A ScrollView / ViewThatFits otherwise fills
                // the whole 340pt and leaves empty space around short lists.
                ScrollView {
                    VStack(spacing: 0) {
                        content
                    }
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        contentHeight = height
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: min(contentHeight, maxListHeight))
            }
            .frame(maxWidth: 320)
            .background(Theme.card)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.border, lineWidth: 0.5)
            )
            .padding(.horizontal, 32)
        }
    }
}

/// A row inside a PickerModal with a fixed check slot.
struct PickerRow: View {
    let label: String
    var isActive = false
    var showCheck = true
    var badge: String?
    var iconName: String?
    var iconColor: Color = Theme.textSecondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if showCheck {
                    ZStack {
                        if isActive {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .frame(width: 22)
                }
                if let iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 15))
                        .foregroundStyle(iconColor)
                }
                Text(label)
                    .font(.system(size: 15, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? .white : Theme.textPrimary)
                    .lineLimit(1)
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Theme.input)
                        .clipShape(.rect(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 13)
            .background(isActive ? Theme.accent.opacity(0.08) : .clear)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.border).frame(height: 0.5)
            }
        }
        .buttonStyle(.plain)
    }
}
