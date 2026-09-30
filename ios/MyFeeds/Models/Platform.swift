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
    case facebook
    case appleMusic = "apple_music"
    case applePodcasts = "apple_podcasts"
    case appleBooks = "apple_books"
    case youtubeMusic = "youtube_music"
    /// Spotify artist pages and shows, found on People. They open in Spotify;
    /// they can't be added as sources (see addable).
    case spotify

    /// Platforms a source can be added from, in the Add Source grids.
    static var addable: [SourcePlatform] { allCases.filter(\.isFollowable) }

    /// False for Spotify, which only opens.
    var isFollowable: Bool { self != .spotify }

    /// Unknown or missing values (rows written before the migration) are YouTube.
    init(raw: String?) {
        self = SourcePlatform(rawValue: raw ?? "") ?? .youtube
    }

    /// Non-YouTube items store "<platform>:<id>" in items.video_id
    /// (x, reddit, instagram, linkedin, github, tiktok, facebook, apple_music, apple_podcasts, apple_books, youtube_music).
    static func isPostVideoId(_ videoId: String?) -> Bool {
        guard let videoId else { return false }
        return ["x:", "reddit:", "instagram:", "linkedin:", "github:", "tiktok:", "facebook:", "apple_music:", "apple_podcasts:", "apple_books:", "youtube_music:"].contains { videoId.hasPrefix($0) }
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
        case .facebook: return "Facebook"
        case .appleMusic: return "Apple Music"
        case .applePodcasts: return "Apple Podcasts"
        case .appleBooks: return "Apple Books"
        case .youtubeMusic: return "YouTube Music"
        case .spotify: return "Spotify"
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
        case .facebook: return "FB"
        case .appleMusic: return "AM"
        case .applePodcasts: return "POD"
        case .appleBooks: return "BK"
        case .youtubeMusic: return "YTM"
        case .spotify: return "SP"
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
        case .facebook: return Color(red: 138 / 255, green: 180 / 255, blue: 1)
        case .appleMusic: return Color(red: 1, green: 138 / 255, blue: 154 / 255)
        case .applePodcasts: return Color(red: 217 / 255, green: 166 / 255, blue: 1)
        case .appleBooks: return Color(red: 1, green: 179 / 255, blue: 92 / 255)
        case .youtubeMusic: return Color(red: 1, green: 138 / 255, blue: 132 / 255)
        case .spotify: return Color(red: 30 / 255, green: 215 / 255, blue: 96 / 255)
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
        case .facebook: return Color(red: 20 / 255, green: 38 / 255, blue: 74 / 255)
        case .appleMusic: return Color(red: 58 / 255, green: 22 / 255, blue: 32 / 255)
        case .applePodcasts: return Color(red: 42 / 255, green: 23 / 255, blue: 64 / 255)
        case .appleBooks: return Color(red: 58 / 255, green: 38 / 255, blue: 16 / 255)
        case .youtubeMusic: return Color(red: 58 / 255, green: 29 / 255, blue: 36 / 255)
        case .spotify: return Color(red: 18 / 255, green: 48 / 255, blue: 29 / 255)
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
        case .facebook: return "Page"
        case .appleMusic: return "Artist"
        case .applePodcasts: return "Show"
        case .appleBooks: return "Author"
        case .youtubeMusic: return "Artist"
        case .spotify: return "Artist"
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
        case .facebook: return "https://www.facebook.com/PageName"
        case .appleMusic: return "Artist name or https://music.apple.com/us/artist/name/123"
        case .applePodcasts: return "Show name or https://podcasts.apple.com/us/podcast/name/id123"
        case .appleBooks: return "Author name or https://books.apple.com/us/author/name/id123"
        case .youtubeMusic: return "Artist name or https://music.youtube.com/channel/UC..."
        case .spotify: return ""
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
        case .facebook: return "Public Pages only. Posts from the lookback window."
        case .appleMusic: return "New singles and albums. Adding an artist also brings in their latest album."
        case .applePodcasts: return "New episodes, played right here. Adding a show also brings in its latest episode."
        case .appleBooks: return "New audiobooks, with a sample to listen to. Adding an author also brings in their latest audiobook."
        case .youtubeMusic: return "New songs, albums and music videos. Adding an artist also brings in their latest album."
        case .spotify: return ""
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
        case .facebook: return "Open on Facebook"
        case .appleMusic: return "Open in Apple Music"
        case .applePodcasts: return "Open in Apple Podcasts"
        case .appleBooks: return "Open in Apple Books"
        case .youtubeMusic: return "Open in YouTube Music"
        case .spotify: return "Open in Spotify"
        }
    }

    /// Newer sources whose data provider is still settling in.
    var isBeta: Bool { self != .youtube && self != .x && self != .reddit && self != .github }
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

/// Engagement numbers for X, Reddit, Instagram, LinkedIn, GitHub, TikTok and Facebook posts (items.metrics).
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
    /// Apple Podcasts episode: the audio file and its length in seconds.
    var audioUrl: String?
    var duration: Int?
    /// Apple Music release: Apple's embed player link, and single / ep / album.
    var embedUrl: String?
    var kind: String?
    var label: String?
    /// Apple Books audiobook: Apple's short sample.
    var previewUrl: String?
    /// YouTube Music: the release's track video ids, or a music video's id.
    var videoIds: [String]?
    var youtubeId: String?

    /// Keys arrive snake_case; the service decoder converts them.
    enum CodingKeys: String, CodingKey {
        case type, url, authorName, authorHandle, authorAvatar, verified, createdAt, text, image, title, preview, videoUrl, hlsUrl
        case audioUrl, duration, embedUrl, kind, label, previewUrl, videoIds, youtubeId
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
        audioUrl = try? c.decodeIfPresent(String.self, forKey: .audioUrl)
        duration = decodeLenientInt(c, .duration)
        embedUrl = try? c.decodeIfPresent(String.self, forKey: .embedUrl)
        kind = try? c.decodeIfPresent(String.self, forKey: .kind)
        label = try? c.decodeIfPresent(String.self, forKey: .label)
        previewUrl = try? c.decodeIfPresent(String.self, forKey: .previewUrl)
        videoIds = try? c.decodeIfPresent([String].self, forKey: .videoIds)
        youtubeId = try? c.decodeIfPresent(String.self, forKey: .youtubeId)
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

// MARK: - Platform from a pasted link

extension SourcePlatform {
    /// Web addresses that tell us which platform a pasted link belongs to.
    /// A subdomain counts too (m.youtube.com, old.reddit.com, vm.tiktok.com).
    private static let hosts: [(String, SourcePlatform)] = [
        // Before youtube.com, which it would otherwise match.
        ("music.youtube.com", .youtubeMusic),
        ("youtube.com", .youtube), ("youtu.be", .youtube),
        ("x.com", .x), ("twitter.com", .x),
        ("reddit.com", .reddit), ("redd.it", .reddit),
        ("instagram.com", .instagram), ("instagr.am", .instagram),
        ("linkedin.com", .linkedin), ("lnkd.in", .linkedin),
        ("github.com", .github),
        ("tiktok.com", .tiktok),
        ("facebook.com", .facebook), ("fb.com", .facebook), ("fb.watch", .facebook),
        ("music.apple.com", .appleMusic),
        ("podcasts.apple.com", .applePodcasts),
        ("books.apple.com", .appleBooks),
    ]

    /// Works out the platform from what the user pasted in Add Source, so an
    /// Instagram link can't be added with YouTube selected. Returns nil when the
    /// text doesn't say (a plain @handle or a name could be any platform).
    static func detect(from value: String) -> SourcePlatform? {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if text.range(of: #"^/?(r|u|user)/[A-Za-z0-9_-]+"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return .reddit
        }

        let hasScheme = text.range(of: #"^[a-z][a-z0-9+.-]*://"#, options: [.regularExpression, .caseInsensitive]) != nil
        guard let components = URLComponents(string: hasScheme ? text : "https://\(text)"),
              var host = components.host?.lowercased(),
              host.contains(".") else { return nil }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        let path = components.path.lowercased()

        // Old iTunes links use one host for both music and podcasts.
        if host == "itunes.apple.com" {
            if path.contains("/podcast") { return .applePodcasts }
            if path.contains("/audiobook") || path.contains("/author") || path.contains("/book/") { return .appleBooks }
            if path.contains("/artist") || path.contains("/album") { return .appleMusic }
            return nil
        }
        for (domain, platform) in hosts where host == domain || host.hasSuffix(".\(domain)") {
            return platform
        }
        return nil
    }
}
