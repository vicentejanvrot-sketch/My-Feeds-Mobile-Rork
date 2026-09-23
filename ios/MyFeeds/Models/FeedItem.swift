import Foundation

/// Row in `item_analysis` joined onto items.
nonisolated struct ItemAnalysis: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var itemId: String?
    var durationSeconds: Int?
    var definition: String?
    var viewsAtAnalysis: Int?
    var likesAtAnalysis: Int?
    var commentsAtAnalysis: Int?
    var analyzedAt: String?
    var shortSummary: String?
    var keyPoints: [String]?
    var tags: [String]?
    var rankingScore: Double?
}

/// Row in `items` with the embedded `item_analysis` join used in the feed.
nonisolated struct FeedItem: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var agentId: String?
    var runId: String?
    var videoId: String?
    var url: String?
    var title: String?
    var thumbnailUrl: String?
    var channelName: String?
    var channelId: String?
    var publishedAt: String?
    var userStatus: ItemStatus?
    var itemAnalysis: [ItemAnalysis]?
    /// Real duration loaded separately when the embedded analysis join cannot
    /// be decoded. This is runtime-only and is absent from normal API rows.
    var resolvedDurationSeconds: Int?

    var analysis: ItemAnalysis? { itemAnalysis?.first }
    var status: ItemStatus { userStatus ?? .notWatched }

    /// Resolve the YouTube video ID from video_id or the URL.
    var resolvedVideoId: String? {
        if let videoId, videoId.range(of: "^[\\w-]{11}$", options: .regularExpression) != nil {
            return videoId
        }
        guard let url, let comps = URLComponents(string: url) else { return videoId }
        if comps.host?.contains("youtu.be") == true {
            let id = comps.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return id.isEmpty ? videoId : id
        }
        return comps.queryItems?.first(where: { $0.name == "v" })?.value ?? videoId
    }

    /// Deterministic fallback stats when analysis is missing (matches companion apps).
    var fallbackSeed: Int {
        var hash = 5381
        for byte in id.utf8 { hash = ((hash << 5) &+ hash) &+ Int(byte) }
        return abs(hash)
    }

    var displayDurationSeconds: Int? { analysis?.durationSeconds ?? resolvedDurationSeconds }
    var displayViews: Int { analysis?.viewsAtAnalysis ?? (1200 + fallbackSeed % 2_500_000) }
    var displayLikes: Int { analysis?.likesAtAnalysis ?? (40 + fallbackSeed % 180_000) }
    var displayComments: Int { analysis?.commentsAtAnalysis ?? (5 + fallbackSeed % 25_000) }
}

/// Lightweight projection of items used by watch-time statistics.
nonisolated struct StatsItem: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var agentId: String?
    var channelId: String?
    var channelName: String?
    var userStatus: ItemStatus?
    var createdAt: String?
    var publishedAt: String?
    /// Set by the database trigger when an item becomes watched/liked.
    var watchedAt: String?
}

/// Lightweight projection of item_analysis used by watch-time statistics.
nonisolated struct StatsDuration: Codable, Hashable, Sendable {
    var itemId: String
    var durationSeconds: Int?
}

/// Lightweight projection used for run item-count grouping.
nonisolated struct RunItemStatus: Codable, Hashable, Sendable {
    var runId: String?
    var userStatus: ItemStatus?
}
