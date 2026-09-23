import SwiftUI
import Observation

enum ToastType {
    case success
    case error
    case info

    var color: Color {
        switch self {
        case .success: return Color(hsl: 142, 66, 50)
        case .error: return Color(hsl: 0, 72, 55)
        case .info: return Color(hsl: 199, 89, 48)
        }
    }

    var icon: String? {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark"
        case .info: return nil
        }
    }
}

/// Global single-toast presenter, auto-dismissing after 1.8s.
@Observable
final class ToastCenter {
    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let type: ToastType

        static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id }
    }

    var current: Toast?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, type: ToastType = .success) {
        dismissTask?.cancel()
        let toast = Toast(message: message, type: type)
        withAnimation(.easeIn(duration: 0.12)) { current = toast }
        switch type {
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error: UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .info: break
        }
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.18)) { self?.current = nil }
        }
    }
}

/// Centered toast overlay host.
struct ToastHost: View {
    @Environment(ToastCenter.self) private var toasts

    var body: some View {
        ZStack {
            if let toast = toasts.current {
                HStack(spacing: 10) {
                    if let icon = toast.type.icon {
                        ZStack {
                            Circle().fill(.white).frame(width: 28, height: 28)
                            Image(systemName: icon)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(toast.type.color)
                        }
                    }
                    Text(toast.message)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(toast.type.color)
                .clipShape(.rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.2), value: toasts.current)
    }
}
