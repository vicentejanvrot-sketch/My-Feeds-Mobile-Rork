import SwiftUI

/// Where a source or item comes from. Keep in sync with src/lib/platforms.ts
/// (web) and expo/lib/platforms.ts, so every app labels sources the same way.
nonisolated enum SourcePlatform: String, Codable, CaseIterable, Hashable, Sendable {
    case youtube
    case x
    case reddit

    /// Unknown or missing values (rows written before the migration) are YouTube.
    init(raw: String?) {
        self = SourcePlatform(rawValue: raw ?? "") ?? .youtube
    }

    /// Non-YouTube items store "x:<id>" / "reddit:<id>" in items.video_id.
    static func isPostVideoId(_ videoId: String?) -> Bool {
        guard let videoId else { return false }
        return videoId.hasPrefix("x:") || videoId.hasPrefix("reddit:")
    }
}

extension SourcePlatform {
    var label: String {
        switch self {
        case .youtube: return "YouTube"
        case .x: return "X"
        case .reddit: return "Reddit"
        }
    }

    var short: String {
        switch self {
        case .youtube: return "YT"
        case .x: return "X"
        case .reddit: return "r/"
        }
    }

    /// Badge text colour on the dark theme.
    var foreground: Color {
        switch self {
        case .youtube: return Color(red: 1, green: 138 / 255, blue: 132 / 255)
        case .x: return Color(red: 241 / 255, green: 243 / 255, blue: 245 / 255)
        case .reddit: return Color(red: 1, green: 154 / 255, blue: 92 / 255)
        }
    }

    /// Badge background colour on the dark theme.
    var background: Color {
        switch self {
        case .youtube: return Color(red: 58 / 255, green: 29 / 255, blue: 36 / 255)
        case .x: return Color(red: 38 / 255, green: 45 / 255, blue: 59 / 255)
        case .reddit: return Color(red: 58 / 255, green: 36 / 255, blue: 24 / 255)
        }
    }

    var sourceNoun: String {
        switch self {
        case .youtube: return "Channel"
        case .x: return "Account"
        case .reddit: return "Subreddit"
        }
    }

    var addPlaceholder: String {
        switch self {
        case .youtube: return "https://www.youtube.com/@ChannelName"
        case .x: return "@handle or https://x.com/handle"
        case .reddit: return "r/subreddit or a reddit.com link"
        }
    }

    var addHelp: String {
        switch self {
        case .youtube: return "Paste the channel link."
        case .x: return "Original posts only. Reposts and replies are skipped."
        case .reddit: return "Top posts from the lookback window."
        }
    }

    var openLabel: String {
        switch self {
        case .youtube: return "Open on YouTube"
        case .x: return "Open on X"
        case .reddit: return "Open on Reddit"
        }
    }
}

/// Small square badge (YT / X / r/), same colours as the web and Expo apps.
struct PlatformBadge: View {
    let platform: SourcePlatform
    var size: CGFloat = 20

    var body: some View {
        Text(platform.short)
            .font(.system(size: size * 0.45, weight: .heavy))
            .foregroundStyle(platform.foreground)
            .frame(width: size, height: size)
            .background(platform.background)
            .clipShape(.rect(cornerRadius: size * 0.3))
            .accessibilityLabel(platform.label)
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

/// Engagement numbers for X posts and Reddit threads (items.metrics).
nonisolated struct ItemMetrics: Codable, Hashable, Sendable {
    var likes: Int?
    var reposts: Int?
    var replies: Int?
    var views: Int?
    var score: Int?
    var comments: Int?

    enum CodingKeys: String, CodingKey { case likes, reposts, replies, views, score, comments }

    init(from decoder: Decoder) throws {
        guard let c = try? decoder.container(keyedBy: CodingKeys.self) else { return }
        likes = decodeLenientInt(c, .likes)
        reposts = decodeLenientInt(c, .reposts)
        replies = decodeLenientInt(c, .replies)
        views = decodeLenientInt(c, .views)
        score = decodeLenientInt(c, .score)
        comments = decodeLenientInt(c, .comments)
    }
}

/// An image or video attached to a post (items.media).
nonisolated struct ItemMedia: Codable, Hashable, Sendable {
    var type: String?
    var url: String?

    enum CodingKeys: String, CodingKey { case type, url }

    init(from decoder: Decoder) throws {
        guard let c = try? decoder.container(keyedBy: CodingKeys.self) else { return }
        type = try? c.decodeIfPresent(String.self, forKey: .type)
        url = try? c.decodeIfPresent(String.self, forKey: .url)
    }
}
