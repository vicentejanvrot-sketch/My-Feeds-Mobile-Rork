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
        case .notWatched: return String(localized: "New", bundle: .appStrings)
        case .watched: return String(localized: "Seen", bundle: .appStrings)
        case .liked: return String(localized: "Liked", bundle: .appStrings)
        case .watchLater: return String(localized: "Later", bundle: .appStrings)
        }
    }

    /// One item's status ("Marked as Seen"); `label` is the filter / tab name.
    /// Separate keys because Portuguese uses the plural for filters (Vistos)
    /// and the singular for a single item (Visto).
    var actionLabel: String {
        switch self {
        case .notWatched: return String(localized: "status.single.new", defaultValue: "New", bundle: .appStrings)
        case .watched: return String(localized: "status.single.seen", defaultValue: "Seen", bundle: .appStrings)
        case .liked: return String(localized: "status.single.liked", defaultValue: "Liked", bundle: .appStrings)
        case .watchLater: return String(localized: "status.single.later", defaultValue: "Later", bundle: .appStrings)
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
        case .running: return String(localized: "Running", bundle: .appStrings)
        case .success: return String(localized: "Success", bundle: .appStrings)
        case .partial: return String(localized: "Partial", bundle: .appStrings)
        case .failed: return String(localized: "Failed", bundle: .appStrings)
        case .cancelled: return String(localized: "Cancelled", bundle: .appStrings)
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
