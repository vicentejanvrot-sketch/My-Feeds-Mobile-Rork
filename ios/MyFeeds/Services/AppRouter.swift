import Foundation
import Observation
import SwiftUI

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

/// A web app link (https://webapp.myfeeds.ca/...) translated to a screen in the
/// app. Same paths as the web app's routes, so a link from an email, a message
/// or the browser lands on the matching screen. Keep in sync with
/// expo/app/+native-intent.tsx and the web app's
/// public/.well-known/apple-app-site-association.
enum WebLink: Equatable {
    case dashboard
    case feed(agentId: String?, status: ItemStatus?)
    case agents
    case agentDetail(String)
    case agentForm(String?)
    case history
    case following(agentId: String?)
    case settings

    static let hosts: Set<String> = ["webapp.myfeeds.ca"]

    /// nil when the URL isn't one of ours, so other links are left alone.
    init?(url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = url.host?.lowercased(), WebLink.hosts.contains(host) else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func param(_ name: String) -> String? {
            guard let value = query.first(where: { $0.name == name })?.value, !value.isEmpty else { return nil }
            return value
        }

        switch parts.first ?? "" {
        case "":
            self = .dashboard
        case "feed":
            self = .feed(agentId: param("agent"), status: param("status").flatMap(ItemStatus.init(rawValue:)))
        case "agents":
            if parts.count == 1 {
                self = .agents
            } else if parts[1] == "new" {
                self = .agentForm(nil)
            } else if parts.count >= 3, parts[2] == "edit" {
                self = .agentForm(parts[1])
            } else {
                self = .agentDetail(parts[1])
            }
        // The app has no run detail screen, so a run opens History.
        case "history", "runs":
            self = .history
        case "following":
            self = .following(agentId: param("agent"))
        case "settings":
            self = .settings
        default:
            self = .dashboard
        }
    }
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
    /// Navigation stack of the Collections tab, so a link can open a
    /// collection, its edit form or its People list.
    var agentsPath = NavigationPath()
    /// A link that arrived before sign-in finished. Opened once the tabs show.
    var pendingLink: WebLink?
    private var lastLinkURL: URL?
    private var lastLinkAt = Date.distantPast

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

    /// Entry point for links opened from outside the app (universal links).
    /// Returns false for URLs that aren't My Feeds web links.
    @discardableResult
    func handleIncoming(_ url: URL, signedIn: Bool) -> Bool {
        guard let link = WebLink(url: url) else { return false }
        // onOpenURL and the browsing activity can both deliver the same link.
        if url == lastLinkURL, Date().timeIntervalSince(lastLinkAt) < 2 { return true }
        lastLinkURL = url
        lastLinkAt = Date()
        if signedIn {
            open(link)
        } else {
            pendingLink = link
        }
        return true
    }

    /// Called when the tabs appear after sign-in.
    func openPendingLink() {
        guard let link = pendingLink else { return }
        pendingLink = nil
        open(link)
    }

    private func open(_ link: WebLink) {
        playerRequest = nil
        postRequest = nil
        switch link {
        case .dashboard:
            selectedTab = .dashboard
        case .feed(let agentId, let status):
            openFeed(agentId: agentId, status: status)
        case .agents:
            agentsPath = NavigationPath()
            selectedTab = .agents
        case .agentDetail(let agentId):
            pushOnAgents(.agentDetail(agentId))
        case .agentForm(let agentId):
            pushOnAgents(.agentForm(agentId))
        case .history:
            selectedTab = .history
        case .following(let agentId):
            pushOnAgents(agentId.map { .followingIn($0) } ?? .following)
        case .settings:
            selectedTab = .settings
        }
    }

    private func pushOnAgents(_ route: AppRoute) {
        var path = NavigationPath()
        path.append(route)
        agentsPath = path
        selectedTab = .agents
    }
}
