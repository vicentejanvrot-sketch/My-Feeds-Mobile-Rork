import Foundation
import Observation

/// Video-player launch request (presented as a full-screen cover).
struct PlayerRequest: Identifiable, Equatable {
    let id = UUID()
    let videoId: String
    let itemId: String?
}

/// A status change made in the player, so the feed can update immediately
/// instead of waiting for the network write and a full reload.
struct ItemStatusChange: Equatable {
    let id = UUID()
    let itemId: String
    let status: ItemStatus
}

/// Cross-tab feed deep-link (from Dashboard feed cards).
struct FeedRequest: Equatable {
    let agentId: String?
    let status: ItemStatus?
}

enum AppTab: Hashable {
    case dashboard
    case agents
    case feed
    case history
    case settings
}

/// Global navigation coordinator shared across tabs.
@Observable
final class AppRouter {
    var selectedTab: AppTab = .dashboard
    var feedRequest: FeedRequest?
    var playerRequest: PlayerRequest?
    var lastStatusChange: ItemStatusChange?
    /// Status writes still in flight. A feed reload applies these so it can't
    /// briefly bring back the old status before Supabase has saved the new one.
    var pendingStatuses: [String: ItemStatus] = [:]

    func openFeed(agentId: String?, status: ItemStatus?) {
        feedRequest = FeedRequest(agentId: agentId, status: status)
        selectedTab = .feed
    }

    func openVideo(videoId: String, itemId: String?) {
        playerRequest = PlayerRequest(videoId: videoId, itemId: itemId)
    }

    func reportStatusChange(itemId: String, status: ItemStatus) {
        pendingStatuses[itemId] = status
        lastStatusChange = ItemStatusChange(itemId: itemId, status: status)
    }

    func settleStatusChange(itemId: String) {
        pendingStatuses[itemId] = nil
    }
}
