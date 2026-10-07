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
    /// Spotify artists: new releases come from Apple's catalogue and play in
    /// Spotify's player (see add-source / run-agent). Spotify podcast shows are
    /// found on People but only open in Spotify.
    case spotify

    /// Platforms a source can be added from, in the Add Source grids.
    static var addable: [SourcePlatform] { allCases }

    /// True when an account found on People can be followed as a source.
    /// Spotify artists can; Spotify podcast shows only open in Spotify.
    static func isFollowableAccount(_ platform: SourcePlatform, url: String) -> Bool {
        platform != .spotify || !url.contains("/show/")
    }

    /// Unknown or missing values (rows written before the migration) are YouTube.
    init(raw: String?) {
        self = SourcePlatform(rawValue: raw ?? "") ?? .youtube
    }

    /// Non-YouTube items store "<platform>:<id>" in items.video_id
    /// (x, reddit, instagram, linkedin, github, tiktok, facebook, apple_music, apple_podcasts, apple_books, youtube_music).
    static func isPostVideoId(_ videoId: String?) -> Bool {
        guard let videoId else { return false }
        return ["x:", "reddit:", "instagram:", "linkedin:", "github:", "tiktok:", "facebook:", "apple_music:", "apple_podcasts:", "apple_books:", "youtube_music:", "spotify:"].contains { videoId.hasPrefix($0) }
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
        case .youtube: return String(localized: "Channel", bundle: .appStrings)
        case .x: return String(localized: "Account", bundle: .appStrings)
        case .reddit: return String(localized: "Subreddit or user", bundle: .appStrings)
        case .instagram: return String(localized: "Account", bundle: .appStrings)
        case .linkedin: return String(localized: "Profile or company", bundle: .appStrings)
        case .github: return String(localized: "User or organization", bundle: .appStrings)
        case .tiktok: return String(localized: "Account", bundle: .appStrings)
        case .facebook: return String(localized: "Page", bundle: .appStrings)
        case .appleMusic: return String(localized: "Artist", bundle: .appStrings)
        case .applePodcasts: return String(localized: "Show", bundle: .appStrings)
        case .appleBooks: return String(localized: "Author", bundle: .appStrings)
        case .youtubeMusic: return String(localized: "Artist", bundle: .appStrings)
        case .spotify: return String(localized: "Artist", bundle: .appStrings)
        }
    }

    var addPlaceholder: String {
        switch self {
        case .youtube: return "https://www.youtube.com/@ChannelName"
        case .x: return String(localized: "@handle or https://x.com/handle", bundle: .appStrings)
        case .reddit: return String(localized: "r/subreddit, u/username or a reddit.com link", bundle: .appStrings)
        case .instagram: return String(localized: "@handle or https://www.instagram.com/handle", bundle: .appStrings)
        case .linkedin: return "https://www.linkedin.com/in/name or /company/name"
        case .github: return String(localized: "@username or https://github.com/username", bundle: .appStrings)
        case .tiktok: return String(localized: "@username or https://www.tiktok.com/@username", bundle: .appStrings)
        case .facebook: return "https://www.facebook.com/PageName"
        case .appleMusic: return String(localized: "Artist name or https://music.apple.com/us/artist/name/123", bundle: .appStrings)
        case .applePodcasts: return String(localized: "Show name or https://podcasts.apple.com/us/podcast/name/id123", bundle: .appStrings)
        case .appleBooks: return String(localized: "Author name or https://books.apple.com/us/author/name/id123", bundle: .appStrings)
        case .youtubeMusic: return String(localized: "Artist name or https://music.youtube.com/channel/UC...", bundle: .appStrings)
        case .spotify: return "https://open.spotify.com/artist/..."
        }
    }

    var addHelp: String {
        switch self {
        case .youtube: return String(localized: "Paste the channel link.", bundle: .appStrings)
        case .x: return String(localized: "Original posts only. Reposts and replies are skipped.", bundle: .appStrings)
        case .reddit: return String(localized: "Top posts from a subreddit, or a user's own posts, from the lookback window.", bundle: .appStrings)
        case .instagram: return String(localized: "Public accounts only. Posts and reels from the lookback window.", bundle: .appStrings)
        case .linkedin: return String(localized: "Paste a person's profile link or a company page link.", bundle: .appStrings)
        case .github: return String(localized: "New repositories and releases from the lookback window.", bundle: .appStrings)
        case .tiktok: return String(localized: "Public accounts only. Videos from the lookback window.", bundle: .appStrings)
        case .facebook: return String(localized: "Public Pages only. Posts from the lookback window.", bundle: .appStrings)
        case .appleMusic: return String(localized: "New singles and albums. Adding an artist also brings in their latest album.", bundle: .appStrings)
        case .applePodcasts: return String(localized: "New episodes, played right here. Adding a show also brings in its latest episode.", bundle: .appStrings)
        case .appleBooks: return String(localized: "New audiobooks, with a sample to listen to. Adding an author also brings in their latest audiobook.", bundle: .appStrings)
        case .youtubeMusic: return String(localized: "New songs, albums and music videos. Adding an artist also brings in their latest album.", bundle: .appStrings)
        case .spotify: return String(localized: "New singles and albums, played with Spotify's player. Paste the artist's Spotify link. Adding an artist also brings in their latest album.", bundle: .appStrings)
        }
    }

    var openLabel: String {
        switch self {
        case .youtube: return String(localized: "Open on YouTube", bundle: .appStrings)
        case .x: return String(localized: "Open on X", bundle: .appStrings)
        case .reddit: return String(localized: "Open on Reddit", bundle: .appStrings)
        case .instagram: return String(localized: "Open on Instagram", bundle: .appStrings)
        case .linkedin: return String(localized: "Open on LinkedIn", bundle: .appStrings)
        case .github: return String(localized: "Open on GitHub", bundle: .appStrings)
        case .tiktok: return String(localized: "Open on TikTok", bundle: .appStrings)
        case .facebook: return String(localized: "Open on Facebook", bundle: .appStrings)
        case .appleMusic: return String(localized: "Open in Apple Music", bundle: .appStrings)
        case .applePodcasts: return String(localized: "Open in Apple Podcasts", bundle: .appStrings)
        case .appleBooks: return String(localized: "Open in Apple Books", bundle: .appStrings)
        case .youtubeMusic: return String(localized: "Open in YouTube Music", bundle: .appStrings)
        case .spotify: return String(localized: "Open in Spotify", bundle: .appStrings)
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
    /// Spotify release: the Apple Music link it was found from, so the reader
    /// can look for the Spotify match again while Spotify's player isn't known yet.
    var sourceUrl: String?

    /// Keys arrive snake_case; the service decoder converts them.
    enum CodingKeys: String, CodingKey {
        case type, url, authorName, authorHandle, authorAvatar, verified, createdAt, text, image, title, preview, videoUrl, hlsUrl
        case audioUrl, duration, embedUrl, kind, label, previewUrl, videoIds, youtubeId, sourceUrl
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
        sourceUrl = try? c.decodeIfPresent(String.self, forKey: .sourceUrl)
    }

    /// `label` as shown to the user. The server writes a few fixed English
    /// labels ("New single", "Latest album", ...); those are shown in the app's
    /// language, anything else as it is.
    var displayLabel: String? {
        guard let label, !label.isEmpty else { return nil }
        switch label {
        case "New single": return String(localized: "New single", bundle: .appStrings)
        case "New EP": return String(localized: "New EP", bundle: .appStrings)
        case "New album": return String(localized: "New album", bundle: .appStrings)
        case "Latest album": return String(localized: "Latest album", bundle: .appStrings)
        case "New audiobook": return String(localized: "New audiobook", bundle: .appStrings)
        case "Latest audiobook": return String(localized: "Latest audiobook", bundle: .appStrings)
        default: return label
        }
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
        ("open.spotify.com", .spotify),
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
