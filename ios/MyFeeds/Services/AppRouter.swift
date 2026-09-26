import Foundation
import Observation

/// Video-player launch request (presented as a full-screen cover).
struct PlayerRequest: Identifiable, Equatable {
    let id = UUID()
    let videoId: String
    let itemId: String?
}

/// Post-reader launch request for X posts and Reddit threads (presented as a sheet).
struct PostRequest: Identifiable, Equatable {
    let id = UUID()
    let itemId: String
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
    var postRequest: PostRequest?
    var lastStatusChange: ItemStatusChange?
    /// Status writes still in flight. A feed reload applies these so it can't
    /// briefly bring back the old status before Supabase has saved the new one.
    var pendingStatuses: [String: ItemStatus] = [:]

    func openFeed(agentId: String?, status: ItemStatus?) {
        feedRequest = FeedRequest(agentId: agentId, status: status)
        selectedTab = .feed
    }

    /// Opens a YouTube video in the player, or an X/Reddit post in the reader.
    /// Every "open" in the app goes through here, so posts never reach the player.
    func openVideo(videoId: String, itemId: String?) {
        if SourcePlatform.isPostVideoId(videoId) {
            if let itemId { openPost(itemId: itemId) }
            return
        }
        playerRequest = PlayerRequest(videoId: videoId, itemId: itemId)
    }

    func openPost(itemId: String) {
        postRequest = PostRequest(itemId: itemId)
    }

    func reportStatusChange(itemId: String, status: ItemStatus) {
        pendingStatuses[itemId] = status
        lastStatusChange = ItemStatusChange(itemId: itemId, status: status)
    }

    func settleStatusChange(itemId: String) {
        pendingStatuses[itemId] = nil
    }
}
