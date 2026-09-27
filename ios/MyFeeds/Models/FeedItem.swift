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
    /// Timestamped moments from the video transcript (YouTube only).
    var keyMoments: [KeyMoment]?
    /// "transcript" | "metadata" | "post" | "thread"
    var summarySource: String?

    /// Key moments with text, in time order.
    var moments: [KeyMoment] {
        (keyMoments ?? []).filter { !$0.text.isEmpty }.sorted { $0.seconds < $1.seconds }
    }

    var isFromTranscript: Bool { summarySource == "transcript" }
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
    /// "youtube" | "x" | "reddit" | "instagram" | "linkedin". Missing on rows created before multi-platform sources.
    var platform: String?
    /// Post text (X, Instagram caption, LinkedIn) or self-text (Reddit).
    var body: String?
    var authorHandle: String?
    var metrics: ItemMetrics?
    var media: [ItemMedia]?
    /// Real duration loaded separately when the embedded analysis join cannot
    /// be decoded. This is runtime-only and is absent from normal API rows.
    var resolvedDurationSeconds: Int?

    var analysis: ItemAnalysis? { itemAnalysis?.first }
    var status: ItemStatus { userStatus ?? .notWatched }

    var sourcePlatform: SourcePlatform {
        if let platform { return SourcePlatform(raw: platform) }
        return SourcePlatform.fromVideoId(videoId)
    }

    /// Posts (X, Reddit, Instagram, LinkedIn) open in the reader, not the video player.
    var isPost: Bool { sourcePlatform != .youtube || SourcePlatform.isPostVideoId(videoId) }

    /// Quoted post or X article shown as a card inside the post.
    var quoteEmbed: ItemMedia? { media?.first(where: { $0.isEmbed }) }

    /// Video attached to the post itself (not to a quoted post).
    var postVideo: ItemMedia? { media?.first(where: { !$0.isEmbed && $0.playableURL != nil }) }

    /// Every photo attached to the post, for Instagram and LinkedIn carousels.
    var postPhotoURLs: [URL] {
        (media ?? []).compactMap { m -> URL? in
            guard m.type != "video", !m.isEmbed, var raw = m.url, !raw.isEmpty else { return nil }
            if raw.hasPrefix("http://") { raw = "https://" + raw.dropFirst("http://".count) }
            return URL(string: raw)
        }
    }

    /// First image attached to a post, or its stored thumbnail.
    var postImageURL: URL? {
        let attached = media?.first(where: { $0.type != "video" && !$0.isEmbed && ($0.url?.isEmpty == false) })?.url
        let raw = attached ?? (quoteEmbed == nil ? thumbnailUrl : nil)
        guard var raw, !raw.isEmpty else { return nil }
        if raw.hasPrefix("http://") { raw = "https://" + raw.dropFirst("http://".count) }
        return URL(string: raw)
    }

    /// Resolve the YouTube video ID from video_id or the URL.
    var resolvedVideoId: String? {
        if let videoId, videoId.range(of: "^[\\w-]{11}$", options: .regularExpression) != nil {
            return videoId
        }
        // "<platform>:<id>" post ids are kept as-is so the router can open the reader.
        if SourcePlatform.isPostVideoId(videoId) { return videoId }
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
