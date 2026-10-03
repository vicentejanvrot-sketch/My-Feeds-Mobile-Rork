import SwiftUI

/// Watch status shared by items and channels.
nonisolated enum ItemStatus: String, Codable, CaseIterable, Sendable {
    case notWatched = "not_watched"
    case watched
    case liked
    case watchLater = "watch_later"
}

extension ItemStatus {
    var label: String {
        switch self {
        case .notWatched: return "New"
        case .watched: return "Seen"
        case .liked: return "Liked/Saved"
        case .watchLater: return "Later"
        }
    }

    var actionLabel: String {
        switch self {
        case .notWatched: return "New"
        case .watched: return "Seen"
        case .liked: return "Liked"
        case .watchLater: return "Later"
        }
    }

    var icon: String {
        switch self {
        case .notWatched: return "circle"
        case .watched: return "checkmark"
        case .liked: return "heart.fill"
        case .watchLater: return "clock"
        }
    }

    var color: Color {
        switch self {
        case .notWatched: return Theme.textMuted
        case .watched: return Theme.success
        case .liked: return Theme.destructive
        case .watchLater: return Theme.warning
        }
    }
}

/// Agent run status.
nonisolated enum RunStatus: String, Codable, Sendable {
    case running
    case success
    case partial
    case failed
    case cancelled
}

extension RunStatus {
    var label: String {
        switch self {
        case .running: return "Running"
        case .success: return "Success"
        case .partial: return "Partial"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    var icon: String {
        switch self {
        case .running: return "clock"
        case .success: return "checkmark.circle"
        case .partial: return "exclamationmark.triangle"
        case .failed: return "xmark.circle"
        case .cancelled: return "nosign"
        }
    }

    var color: Color {
        switch self {
        case .running: return Theme.accent
        case .success: return Theme.success
        case .partial: return Theme.warning
        case .failed: return Theme.destructive
        case .cancelled: return Theme.textMuted
        }
    }
}
