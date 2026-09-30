import SwiftUI

/// Where a source or item comes from. Keep in sync with src/lib/platforms.ts
/// (web) and expo/lib/platforms.ts, so every app labels sources the same way.
nonisolated enum SourcePlatform: String, Codable, CaseIterable, Hashable, Sendable {
    case youtube
    case x
    case reddit
    case instagram
    case linkedin
    case github
    case tiktok

    /// Unknown or missing values (rows written before the migration) are YouTube.
    init(raw: String?) {
        self = SourcePlatform(rawValue: raw ?? "") ?? .youtube
    }

    /// Non-YouTube items store "<platform>:<id>" in items.video_id
    /// (x, reddit, instagram, linkedin, github, tiktok).
    static func isPostVideoId(_ videoId: String?) -> Bool {
        guard let videoId else { return false }
        return ["x:", "reddit:", "instagram:", "linkedin:", "github:", "tiktok:"].contains { videoId.hasPrefix($0) }
    }

    /// Platform of a post item from its "<platform>:<id>" video_id; YouTube otherwise.
    static func fromVideoId(_ videoId: String?) -> SourcePlatform {
        guard let videoId, let prefix = videoId.split(separator: ":", maxSplits: 1).first,
              videoId.contains(":"),
              let platform = SourcePlatform(rawValue: String(prefix)) else { return .youtube }
        return platform
    }
}

extension SourcePlatform {
    var label: String {
        switch self {
        case .youtube: return "YouTube"
        case .x: return "X"
        case .reddit: return "Reddit"
        case .instagram: return "Instagram"
        case .linkedin: return "LinkedIn"
        case .github: return "GitHub"
        case .tiktok: return "TikTok"
        }
    }

    var short: String {
        switch self {
        case .youtube: return "YT"
        case .x: return "X"
        case .reddit: return "r/"
        case .instagram: return "IG"
        case .linkedin: return "in"
        case .github: return "GH"
        case .tiktok: return "TT"
        }
    }

    /// Badge text colour on the dark theme.
    var foreground: Color {
        switch self {
        case .youtube: return Color(red: 1, green: 138 / 255, blue: 132 / 255)
        case .x: return Color(red: 241 / 255, green: 243 / 255, blue: 245 / 255)
        case .reddit: return Color(red: 1, green: 154 / 255, blue: 92 / 255)
        case .instagram: return Color(red: 1, green: 122 / 255, blue: 178 / 255)
        case .linkedin: return Color(red: 127 / 255, green: 184 / 255, blue: 240 / 255)
        case .github: return Color(red: 230 / 255, green: 237 / 255, blue: 243 / 255)
        case .tiktok: return Color(red: 241 / 255, green: 243 / 255, blue: 245 / 255)
        }
    }

    /// Badge background colour on the dark theme.
    var background: Color {
        switch self {
        case .youtube: return Color(red: 58 / 255, green: 29 / 255, blue: 36 / 255)
        case .x: return Color(red: 38 / 255, green: 45 / 255, blue: 59 / 255)
        case .reddit: return Color(red: 58 / 255, green: 36 / 255, blue: 24 / 255)
        case .instagram: return Color(red: 58 / 255, green: 24 / 255, blue: 48 / 255)
        case .linkedin: return Color(red: 20 / 255, green: 40 / 255, blue: 61 / 255)
        case .github: return Color(red: 33 / 255, green: 38 / 255, blue: 45 / 255)
        case .tiktok: return Color(red: 31 / 255, green: 31 / 255, blue: 36 / 255)
        }
    }

    var sourceNoun: String {
        switch self {
        case .youtube: return "Channel"
        case .x: return "Account"
        case .reddit: return "Subreddit or user"
        case .instagram: return "Account"
        case .linkedin: return "Profile or company"
        case .github: return "User or organization"
        case .tiktok: return "Account"
        }
    }

    var addPlaceholder: String {
        switch self {
        case .youtube: return "https://www.youtube.com/@ChannelName"
        case .x: return "@handle or https://x.com/handle"
        case .reddit: return "r/subreddit, u/username or a reddit.com link"
        case .instagram: return "@handle or https://www.instagram.com/handle"
        case .linkedin: return "https://www.linkedin.com/in/name or /company/name"
        case .github: return "@username or https://github.com/username"
        case .tiktok: return "@username or https://www.tiktok.com/@username"
        }
    }

    var addHelp: String {
        switch self {
        case .youtube: return "Paste the channel link."
        case .x: return "Original posts only. Reposts and replies are skipped."
        case .reddit: return "Top posts from a subreddit, or a user's own posts, from the lookback window."
        case .instagram: return "Public accounts only. Posts and reels from the lookback window."
        case .linkedin: return "Paste a person's profile link or a company page link."
        case .github: return "New repositories and releases from the lookback window."
        case .tiktok: return "Public accounts only. Videos from the lookback window."
        }
    }

    var openLabel: String {
        switch self {
        case .youtube: return "Open on YouTube"
        case .x: return "Open on X"
        case .reddit: return "Open on Reddit"
        case .instagram: return "Open on Instagram"
        case .linkedin: return "Open on LinkedIn"
        case .github: return "Open on GitHub"
        case .tiktok: return "Open on TikTok"
        }
    }

    /// Newer sources whose data provider is still settling in.
    var isBeta: Bool { self == .instagram || self == .linkedin || self == .tiktok }
}

/// Platform logo used on cards, lists and filters, same look as the web and Expo apps.
struct PlatformBadge: View {
    let platform: SourcePlatform
    var size: CGFloat = 20

    var body: some View {
        PlatformLogo(platform: platform)
            .frame(width: size, height: size)
            .accessibilityElement()
            .accessibilityLabel(platform.label)
            .accessibilityAddTraits(.isImage)
    }
}

// MARK: - JSON helpers

/// Decodes a number whether the JSON holds an int, a double or a numeric string.
/// jsonb columns are written by different code paths, so be forgiving.
nonisolated private func decodeLenientInt<K: CodingKey>(_ container: KeyedDecodingContainer<K>, _ key: K) -> Int? {
    if let value = try? container.decodeIfPresent(Int.self, forKey: key) { return value }
    if let value = try? container.decodeIfPresent(Double.self, forKey: key), value.isFinite { return Int(value) }
    if let value = try? container.decodeIfPresent(String.self, forKey: key) { return Int(value) }
    return nil
}

/// A timestamped moment from a video transcript summary.
nonisolated struct KeyMoment: Codable, Hashable, Sendable {
    var seconds: Int
    var text: String

    enum CodingKeys: String, CodingKey { case seconds, text }

    init(seconds: Int, text: String) {
        self.seconds = seconds
        self.text = text
    }

    /// Never throws, so one odd entry can't break the whole feed decode.
    /// Entries without text are dropped by `ItemAnalysis.moments`.
    init(from decoder: Decoder) throws {
        guard let c = try? decoder.container(keyedBy: CodingKeys.self) else {
            seconds = 0
            text = ""
            return
        }
        seconds = max(decodeLenientInt(c, .seconds) ?? 0, 0)
        text = (try? c.decodeIfPresent(String.self, forKey: .text)) ?? ""
    }

    /// 75 -> "1:15", 3725 -> "1:02:05"
    var clock: String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

/// Engagement numbers for X, Reddit, Instagram, LinkedIn, GitHub and TikTok posts (items.metrics).
nonisolated struct ItemMetrics: Codable, Hashable, Sendable {
    var likes: Int?
    var reposts: Int?
    var replies: Int?
    var views: Int?
    var bookmarks: Int?
    var quotes: Int?
    var score: Int?
    var comments: Int?
    /// Instagram reel plays.
    var plays: Int?
    /// GitHub repo stars and forks.
    var stars: Int?
    var forks: Int?

    enum CodingKeys: String, CodingKey { case likes, reposts, replies, views, bookmarks, quotes, score, comments, plays, stars, forks }

    init(from decoder: Decoder) throws {
        guard let c = try? decoder.container(keyedBy: CodingKeys.self) else { return }
        likes = decodeLenientInt(c, .likes)
        reposts = decodeLenientInt(c, .reposts)
        replies = decodeLenientInt(c, .replies)
        views = decodeLenientInt(c, .views)
        bookmarks = decodeLenientInt(c, .bookmarks)
        quotes = decodeLenientInt(c, .quotes)
        score = decodeLenientInt(c, .score)
        comments = decodeLenientInt(c, .comments)
        plays = decodeLenientInt(c, .plays)
        stars = decodeLenientInt(c, .stars)
        forks = decodeLenientInt(c, .forks)
    }
}

/// An image attached to a post, or a quoted post / X article shown as a card
/// (type "quote" / "article") — items.media.
nonisolated struct ItemMedia: Codable, Hashable, Sendable {
    var type: String?
    var url: String?
    var authorName: String?
    var authorHandle: String?
    var authorAvatar: String?
    var verified: Bool?
    var createdAt: String?
    var text: String?
    var image: String?
    var title: String?
    var preview: String?
    /// Playable video: MP4, and an HLS stream (plays with sound).
    var videoUrl: String?
    var hlsUrl: String?

    /// Keys arrive snake_case; the service decoder converts them.
    enum CodingKeys: String, CodingKey {
        case type, url, authorName, authorHandle, authorAvatar, verified, createdAt, text, image, title, preview, videoUrl, hlsUrl
    }

    init(from decoder: Decoder) throws {
        guard let c = try? decoder.container(keyedBy: CodingKeys.self) else { return }
        type = try? c.decodeIfPresent(String.self, forKey: .type)
        url = try? c.decodeIfPresent(String.self, forKey: .url)
        authorName = try? c.decodeIfPresent(String.self, forKey: .authorName)
        authorHandle = try? c.decodeIfPresent(String.self, forKey: .authorHandle)
        authorAvatar = try? c.decodeIfPresent(String.self, forKey: .authorAvatar)
        verified = try? c.decodeIfPresent(Bool.self, forKey: .verified)
        createdAt = try? c.decodeIfPresent(String.self, forKey: .createdAt)
        text = try? c.decodeIfPresent(String.self, forKey: .text)
        image = try? c.decodeIfPresent(String.self, forKey: .image)
        title = try? c.decodeIfPresent(String.self, forKey: .title)
        preview = try? c.decodeIfPresent(String.self, forKey: .preview)
        videoUrl = try? c.decodeIfPresent(String.self, forKey: .videoUrl)
        hlsUrl = try? c.decodeIfPresent(String.self, forKey: .hlsUrl)
    }

    /// HLS first (it has sound for Reddit videos), MP4 otherwise.
    var playableURL: URL? {
        for raw in [hlsUrl, videoUrl] {
            if let raw, !raw.isEmpty, let url = URL(string: raw) { return Self.directVideoURL(url) ?? url }
        }
        return nil
    }

    /// Instagram videos are stored behind our media-proxy, but AVPlayer sends
    /// no Referer, so Instagram's CDN serves them directly. Going direct avoids
    /// the extra hop on every chunk, which made playback pause after a second.
    private static func directVideoURL(_ url: URL) -> URL? {
        guard url.path.hasSuffix("/functions/v1/media-proxy"),
              let inner = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "u" })?.value,
              let direct = URL(string: inner),
              let host = direct.host?.lowercased(),
              host.hasSuffix(".cdninstagram.com") || host.hasSuffix(".fbcdn.net") else { return nil }
        return direct
    }

    var isEmbed: Bool { type == "quote" || type == "article" }
    var isArticle: Bool { type == "article" }
}
