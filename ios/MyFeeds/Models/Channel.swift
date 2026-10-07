import Foundation

/// Row in the shared `channels` table. Holds every kind of source:
/// YouTube channels, X accounts and subreddits.
nonisolated struct Channel: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var agentId: String
    var channelUrl: String?
    var channelId: String?
    var uploadsPlaylistId: String?
    var channelName: String?
    var channelThumbnail: String?
    var priority: Int?
    var isEnabled: Bool?
    var userStatus: ItemStatus?
    var lastScannedAt: String?
    var createdAt: String?
    var updatedAt: String?
    /// "youtube" | "x" | "reddit". Missing on rows created before multi-platform sources.
    var platform: String?
    /// "channel" | "account" | "subreddit" | "keyword"
    var sourceType: String?
    /// "@handle" for X, "r/name" for Reddit.
    var handle: String?
    /// Minimum likes (X) or upvotes (Reddit) for a post to reach the feed.
    var minEngagement: Int?
    /// A private account the user follows (a friend's private Instagram): shown
    /// on People with a button to open it, its posts are never fetched.
    var isPrivate: Bool?

    var isPrivateAccount: Bool { isPrivate == true }

    var sourcePlatform: SourcePlatform { SourcePlatform(raw: platform) }

    var displayName: String {
        if let channelName, !channelName.isEmpty { return channelName }
        if let handle, !handle.isEmpty { return handle }
        if let channelUrl, !channelUrl.isEmpty { return channelUrl }
        return String(localized: "Unnamed")
    }
}
