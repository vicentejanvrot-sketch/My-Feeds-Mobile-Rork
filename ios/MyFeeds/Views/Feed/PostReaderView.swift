import AVKit
import SwiftUI
import WebKit

/// In-app reader for X posts, Reddit threads, Instagram, LinkedIn, TikTok and Facebook posts,
/// Apple Music releases and Apple Podcasts episodes. The native twin of the web
/// PostReaderModal and the Expo post-reader screen, so reading works the same
/// everywhere and the user doesn't have to leave My Feeds.
struct PostReaderView: View {
    let request: PostRequest

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(ToastCenter.self) private var toasts
    @Environment(AppRouter.self) private var router

    @State private var item: FeedItem?
    @State private var loadFailed = false
    @State private var status: ItemStatus = .notWatched

    // The action bar copies each platform's own row under a post. In My Feeds:
    // Like / Upvote = Saved, Bookmark / Save = Read Later, the check = Read.
    // Reply and Repost open the post on X, since those happen on the platform.
    private static let xPink = Color(red: 249 / 255, green: 24 / 255, blue: 128 / 255)
    private static let xBlue = Color(red: 29 / 255, green: 155 / 255, blue: 240 / 255)
    private static let redditOrange = Color(red: 1, green: 69 / 255, blue: 0)
    private static let igRed = Color(red: 1, green: 48 / 255, blue: 64 / 255)
    private static let linkedInBlue = Color(red: 55 / 255, green: 143 / 255, blue: 233 / 255)
    private static let gitHubStar = Color(red: 227 / 255, green: 179 / 255, blue: 65 / 255)
    private static let tikTokRed = Color(red: 254 / 255, green: 44 / 255, blue: 85 / 255)
    private static let tikTokYellow = Color(red: 250 / 255, green: 206 / 255, blue: 21 / 255)
    private static let facebookBlue = Color(red: 8 / 255, green: 102 / 255, blue: 1)
    private static let appleMusicRed = Color(red: 250 / 255, green: 36 / 255, blue: 60 / 255)
    private static let applePodcastsPurple = Color(red: 179 / 255, green: 92 / 255, blue: 242 / 255)

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let item {
                content(item)
            } else if loadFailed {
                VStack(spacing: 12) {
                    Text("Couldn't load this post. Check your connection.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            } else {
                ProgressView()
                    .controlSize(.large)
                    .tint(Theme.accent)
            }
        }
        .task { await load() }
    }

    // MARK: - Content

    private func content(_ item: FeedItem) -> some View {
        let platform = item.sourcePlatform
        return VStack(spacing: 0) {
            header(item, platform: platform)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if platform == .github {
                        Text(item.title ?? "Untitled")
                            .font(.system(size: 19, weight: .heavy))
                            .foregroundStyle(Theme.textPrimary)
                            .lineSpacing(3)
                    }
                    if platform == .reddit {
                        Text(item.title ?? "Untitled")
                            .font(.system(size: 19, weight: .heavy))
                            .foregroundStyle(Theme.textPrimary)
                            .lineSpacing(3)
                        if let author = item.authorHandle, !author.isEmpty {
                            Text(author)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    if let body = item.body, !body.isEmpty {
                        Text(body)
                            .font(.system(size: platform == .reddit ? 15 : 17))
                            .foregroundStyle(Theme.textPrimary)
                            .lineSpacing(platform == .reddit ? 5 : 6)
                            .textSelection(.enabled)
                    } else if platform == .x, let title = item.title {
                        Text(title)
                            .font(.system(size: 17))
                            .foregroundStyle(Theme.textPrimary)
                            .lineSpacing(6)
                            .textSelection(.enabled)
                    }

                    let photos = item.postPhotoURLs
                    let slides = item.carouselMedia
                    if platform == .appleMusic,
                       let release = item.media?.first(where: { $0.type == "album" }),
                       let raw = release.embedUrl, let embedURL = URL(string: raw) {
                        // Apple Music's own player: previews, or full songs when signed in.
                        AppleMusicEmbedPlayer(url: embedURL, single: release.kind == "single")
                    } else if platform == .applePodcasts,
                              let episode = item.media?.first(where: { $0.type == "audio" }),
                              let raw = episode.audioUrl, let audioURL = URL(string: raw),
                              let progressId = item.videoId {
                        PodcastPlayerView(
                            url: audioURL,
                            artwork: episode.url.flatMap(URL.init(string:)),
                            knownDuration: episode.duration,
                            progressId: progressId
                        ) {
                            if status == .notWatched { changeStatus(.watched, item: item) }
                        }
                    } else if platform == .tiktok, photos.isEmpty, let videoId = tikTokVideoId(item) {
                        // TikTok's own player: its CDN links expire, the embed doesn't.
                        TikTokEmbedPlayer(videoId: videoId)
                    } else if platform == .facebook, item.postVideo != nil,
                              let embed = FacebookEmbedPlayer.embed(for: item.url) {
                        // Facebook's own player: its MP4 links expire, the post link doesn't.
                        FacebookEmbedPlayer(url: embed.url, portrait: embed.portrait)
                    } else if slides.count > 1 {
                        MediaCarousel(slides: slides, progressId: item.videoId)
                    } else if let video = item.postVideo, let url = video.playableURL {
                        PostVideoPlayer(url: url, progressId: item.videoId)
                    } else if photos.count > 1 {
                        PhotoCarousel(urls: photos)
                    } else if let imageURL = item.postImageURL {
                        ExpandablePhoto(url: imageURL)
                    }

                    if let quote = item.quoteEmbed {
                        quoteCard(quote)
                    }

                    summaryBox(item, platform: platform)
                    if platform == .youtube {
                        // YouTube videos opened from Downloads: the key moments, to read offline.
                        keyMomentsBox(item)
                    }

                    if let tags = item.analysis?.tags, !tags.isEmpty {
                        FlowLayoutWrap(spacing: 6) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Theme.input)
                                    .clipShape(.rect(cornerRadius: 6))
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }

            footer(item, platform: platform)
        }
    }

    private func header(_ item: FeedItem, platform: SourcePlatform) -> some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Close")

            PlatformBadge(platform: platform)

            Text(headerText(item, platform: platform))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            DownloadButton(itemId: item.id, hasAudio: platform == .applePodcasts)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 0.5)
        }
    }

    private func headerText(_ item: FeedItem, platform: SourcePlatform) -> String {
        let name = item.channelName ?? platform.label
        guard item.publishedAt != nil else { return name }
        return "\(name) · \(Format.timeAgo(item.publishedAt))"
    }

    /// Quoted post or X article, shown as a card inside the post like on X.
    private func quoteCard(_ quote: ItemMedia) -> some View {
        // Not a Button, so a video inside the card still gets its own taps.
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let avatar = quote.authorAvatar, let url = URL(string: avatar) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Theme.input
                        }
                    }
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())
                }
                Text(quote.authorName ?? "")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                if quote.verified == true {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Self.xBlue)
                }
                Text(quoteHandleText(quote))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            if !quote.isArticle, let text = quote.text, !text.isEmpty {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textPrimary)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
            }
            if let url = quote.playableURL {
                PostVideoPlayer(url: url)
            } else if let raw = quote.image, let url = URL(string: raw) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Theme.card
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 12))
            }
            if quote.isArticle {
                if let title = quote.title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                }
                if let preview = quote.preview, !preview.isEmpty {
                    Text(preview)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textPrimary.opacity(0.85))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.border, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if let raw = quote.url, let url = URL(string: raw) { openURL(url) }
        }
        .accessibilityAddTraits(.isLink)
    }

    private func quoteHandleText(_ quote: ItemMedia) -> String {
        let handle = quote.authorHandle ?? ""
        guard quote.createdAt != nil else { return handle }
        return "\(handle) · \(Format.timeAgo(quote.createdAt))"
    }

    /// "12:01 PM · Sep 26, 2026 · 166.5K Views", as under a post on X.
    /// Instagram and LinkedIn show the date only, plus plays for reels.
    private func dateLine(_ item: FeedItem, platform: SourcePlatform) -> Text? {
        guard let raw = item.publishedAt else { return nil }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = parser.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = platform == .x ? "h:mm a · MMM d, yyyy" : "MMM d, yyyy"
        var line = Text(formatter.string(from: date)).foregroundColor(Theme.textSecondary)
        let views = (item.metrics?.views ?? 0) > 0 ? item.metrics?.views : item.metrics?.plays
        if let views, views > 0 {
            line = line
                + Text(" · ").foregroundColor(Theme.textSecondary)
                + Text(Format.compactNumber(views)).bold().foregroundColor(Theme.textPrimary)
                + Text(" Views").foregroundColor(Theme.textSecondary)
        }
        return line
    }

    @ViewBuilder
    private func summaryBox(_ item: FeedItem, platform: SourcePlatform) -> some View {
        let summary = item.analysis?.shortSummary ?? ""
        let points = item.analysis?.keyPoints ?? []
        if !summary.isEmpty || !points.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(platform == .reddit ? "THREAD SUMMARY" : "SUMMARY")
                    .font(.system(size: 11, weight: .heavy))
                    .kerning(0.8)
                    .foregroundStyle(Theme.accent)
                if !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textPrimary)
                        .lineSpacing(4)
                }
                ForEach(points, id: \.self) { point in
                    Text("• \(point)")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textPrimary)
                        .lineSpacing(4)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accent.opacity(0.10))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.accent.opacity(0.25), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func keyMomentsBox(_ item: FeedItem) -> some View {
        let moments = item.analysis?.moments ?? []
        if !moments.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("KEY MOMENTS")
                    .font(.system(size: 11, weight: .heavy))
                    .kerning(0.8)
                    .foregroundStyle(Theme.accent)
                ForEach(moments, id: \.self) { moment in
                    (Text(Self.clock(moment.seconds)).foregroundColor(Theme.accent).bold()
                        + Text("  \(moment.text)").foregroundColor(Theme.textPrimary))
                        .font(.system(size: 14))
                        .lineSpacing(4)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accent.opacity(0.10))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.accent.opacity(0.25), lineWidth: 1)
            )
        }
    }

    private static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }

    private func footer(_ item: FeedItem, platform: SourcePlatform) -> some View {
        VStack(spacing: 10) {
            if platform != .reddit, let line = dateLine(item, platform: platform) {
                line
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
            switch platform {
            case .x: xActionBar(item)
            case .instagram: instagramActionBar(item)
            case .linkedin: linkedInActionBar(item)
            case .github: gitHubActionBar(item)
            case .tiktok: tikTokActionBar(item)
            case .facebook: facebookActionBar(item)
            case .appleMusic, .applePodcasts: appleActionBar(item, platform: platform)
            case .reddit: redditActionBar(item)
            default: EmptyView()
            }

            HStack(spacing: 8) {
                let read = status == .watched
                Button {
                    changeStatus(read ? .notWatched : .watched, item: item)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                        Text(read ? "Read" : "Mark as read")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(read ? Theme.success : Theme.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(read ? Theme.success : Theme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(read ? .isSelected : [])

                Button {
                    if let raw = item.url, let url = URL(string: raw) { openURL(url) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 15))
                        Text(platform.openLabel)
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(item.url == nil)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Theme.card)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.border).frame(height: 0.5)
        }
    }

    // MARK: - Action bars

    private func xActionBar(_ item: FeedItem) -> some View {
        let metrics = item.metrics
        let liked = status == .liked
        let bookmarked = status == .watchLater
        let postId = item.videoId.flatMap { $0.hasPrefix("x:") ? String($0.dropFirst(2)) : nil }
        return HStack {
            barButton(
                icon: "bubble.left",
                value: metrics?.replies ?? 0,
                color: Theme.textSecondary,
                label: "Reply on X"
            ) {
                if let postId { openExternal("https://x.com/intent/post?in_reply_to=\(postId)") }
            }
            Spacer(minLength: 0)
            barButton(
                icon: "arrow.2.squarepath",
                value: metrics?.reposts ?? 0,
                color: Theme.textSecondary,
                label: "Repost on X"
            ) {
                if let postId { openExternal("https://x.com/intent/retweet?tweet_id=\(postId)") }
            }
            Spacer(minLength: 0)
            barButton(
                icon: liked ? "heart.fill" : "heart",
                value: (metrics?.likes ?? 0) + (liked ? 1 : 0),
                color: liked ? Self.xPink : Theme.textSecondary,
                label: liked ? "Remove from Saved" : "Like (save in My Feeds)"
            ) {
                changeStatus(liked ? .watched : .liked, item: item)
            }
            Spacer(minLength: 0)
            barButton(
                icon: bookmarked ? "bookmark.fill" : "bookmark",
                value: (metrics?.bookmarks ?? 0) + (bookmarked ? 1 : 0),
                color: bookmarked ? Self.xBlue : Theme.textSecondary,
                label: bookmarked ? "Remove from Read Later" : "Bookmark (Read Later)"
            ) {
                changeStatus(bookmarked ? .notWatched : .watchLater, item: item)
            }
            Spacer(minLength: 0)
            shareButton(item, color: Theme.textSecondary)
        }
        .padding(.horizontal, 4)
    }

    /// Instagram: like, comment, share on the left, save on the right.
    private func instagramActionBar(_ item: FeedItem) -> some View {
        let metrics = item.metrics
        let liked = status == .liked
        let bookmarked = status == .watchLater
        return HStack(spacing: 4) {
            igButton(
                icon: liked ? "heart.fill" : "heart",
                value: (metrics?.likes ?? 0) + (liked ? 1 : 0),
                color: liked ? Self.igRed : Theme.textPrimary,
                label: liked ? "Remove from Saved" : "Like (save in My Feeds)"
            ) {
                changeStatus(liked ? .watched : .liked, item: item)
            }
            igButton(
                icon: "bubble.right",
                value: metrics?.comments,
                color: Theme.textPrimary,
                label: "Comment on Instagram"
            ) {
                if let raw = item.url { openExternal(raw) }
            }
            if let raw = item.url, let url = URL(string: raw) {
                ShareLink(item: url) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Share")
            }
            Spacer(minLength: 0)
            igButton(
                icon: bookmarked ? "bookmark.fill" : "bookmark",
                value: nil,
                color: Theme.textPrimary,
                label: bookmarked ? "Remove from Read Later" : "Save (Read Later)"
            ) {
                changeStatus(bookmarked ? .notWatched : .watchLater, item: item)
            }
        }
    }

    /// TikTok: like, comment, save, then share, with TikTok's own colours.
    private func tikTokActionBar(_ item: FeedItem) -> some View {
        let metrics = item.metrics
        let liked = status == .liked
        let bookmarked = status == .watchLater
        return HStack(spacing: 4) {
            igButton(
                icon: liked ? "heart.fill" : "heart",
                value: (metrics?.likes ?? 0) + (liked ? 1 : 0),
                color: liked ? Self.tikTokRed : Theme.textPrimary,
                label: liked ? "Remove from Saved" : "Like (save in My Feeds)"
            ) {
                changeStatus(liked ? .watched : .liked, item: item)
            }
            igButton(
                icon: "bubble.right",
                value: metrics?.comments,
                color: Theme.textPrimary,
                label: "Comment on TikTok"
            ) {
                if let raw = item.url { openExternal(raw) }
            }
            igButton(
                icon: bookmarked ? "bookmark.fill" : "bookmark",
                value: nil,
                color: bookmarked ? Self.tikTokYellow : Theme.textPrimary,
                label: bookmarked ? "Remove from Read Later" : "Save (Read Later)"
            ) {
                changeStatus(bookmarked ? .notWatched : .watchLater, item: item)
            }
            Spacer(minLength: 0)
            shareButton(item, color: Theme.textPrimary)
        }
    }

    /// The TikTok video id from "tiktok:<id>" in items.video_id.
    private func tikTokVideoId(_ item: FeedItem) -> String? {
        guard let raw = item.videoId, raw.hasPrefix("tiktok:") else { return nil }
        let id = String(raw.dropFirst("tiktok:".count))
        return id.isEmpty ? nil : id
    }

    private func igButton(icon: String, value: Int?, color: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
                if let value {
                    Text(Format.compactNumber(value))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// Apple Music and Apple Podcasts: heart to save, share, and save for later.
    private func appleActionBar(_ item: FeedItem, platform: SourcePlatform) -> some View {
        let liked = status == .liked
        let bookmarked = status == .watchLater
        let tint = platform == .appleMusic ? Self.appleMusicRed : Self.applePodcastsPurple
        return HStack(spacing: 4) {
            igButton(
                icon: liked ? "heart.fill" : "heart",
                value: nil,
                color: liked ? tint : Theme.textPrimary,
                label: liked ? "Remove from Saved" : "Like (save in My Feeds)"
            ) {
                changeStatus(liked ? .watched : .liked, item: item)
            }
            shareButton(item, color: Theme.textPrimary)
            Spacer(minLength: 0)
            igButton(
                icon: bookmarked ? "bookmark.fill" : "bookmark",
                value: nil,
                color: Theme.textPrimary,
                label: bookmarked ? "Remove from Watch Later" : "Save (Watch Later)"
            ) {
                changeStatus(bookmarked ? .notWatched : .watchLater, item: item)
            }
        }
    }

    /// Facebook: reaction, comment and share counts, then Like, Comment, Share, Save.
    private func facebookActionBar(_ item: FeedItem) -> some View {
        let metrics = item.metrics
        let liked = status == .liked
        let bookmarked = status == .watchLater
        let shares = metrics?.reposts ?? 0
        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "hand.thumbsup.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.white)
                    .frame(width: 16, height: 16)
                    .background(Self.facebookBlue)
                    .clipShape(Circle())
                Text(Format.compactNumber((metrics?.likes ?? 0) + (liked ? 1 : 0)))
                Spacer(minLength: 0)
                Text(shares > 0
                     ? "\(Format.compactNumber(metrics?.comments ?? 0)) comments · \(Format.compactNumber(shares)) shares"
                     : "\(Format.compactNumber(metrics?.comments ?? 0)) comments")
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 4)

            HStack(spacing: 0) {
                linkedInAction(
                    icon: liked ? "hand.thumbsup.fill" : "hand.thumbsup",
                    title: "Like",
                    active: liked,
                    activeColor: Self.facebookBlue
                ) {
                    changeStatus(liked ? .watched : .liked, item: item)
                }
                linkedInAction(icon: "bubble.left", title: "Comment", active: false) {
                    if let raw = item.url { openExternal(raw) }
                }
                if let raw = item.url, let url = URL(string: raw) {
                    ShareLink(item: url) {
                        linkedInLabel(icon: "arrowshape.turn.up.right", title: "Share", active: false)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                } else {
                    linkedInLabel(icon: "arrowshape.turn.up.right", title: "Share", active: false)
                        .frame(maxWidth: .infinity)
                        .opacity(0.4)
                }
                linkedInAction(
                    icon: bookmarked ? "bookmark.fill" : "bookmark",
                    title: "Save",
                    active: bookmarked,
                    activeColor: Self.facebookBlue
                ) {
                    changeStatus(bookmarked ? .notWatched : .watchLater, item: item)
                }
            }
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.border).frame(height: 0.5)
            }
        }
    }

    /// LinkedIn: reaction and comment counts, then Like, Comment, Repost, Send, Save.
    private func linkedInActionBar(_ item: FeedItem) -> some View {
        let metrics = item.metrics
        let liked = status == .liked
        let bookmarked = status == .watchLater
        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "hand.thumbsup.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.white)
                    .frame(width: 16, height: 16)
                    .background(Self.linkedInBlue)
                    .clipShape(Circle())
                Text(Format.compactNumber((metrics?.likes ?? 0) + (liked ? 1 : 0)))
                Spacer(minLength: 0)
                Text("\(Format.compactNumber(metrics?.comments ?? 0)) comments · \(Format.compactNumber(metrics?.reposts ?? 0)) reposts")
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 4)

            HStack(spacing: 0) {
                linkedInAction(
                    icon: liked ? "hand.thumbsup.fill" : "hand.thumbsup",
                    title: "Like",
                    active: liked
                ) {
                    changeStatus(liked ? .watched : .liked, item: item)
                }
                linkedInAction(icon: "text.bubble", title: "Comment", active: false) {
                    if let raw = item.url { openExternal(raw) }
                }
                linkedInAction(icon: "arrow.2.squarepath", title: "Repost", active: false) {
                    if let raw = item.url { openExternal(raw) }
                }
                if let raw = item.url, let url = URL(string: raw) {
                    ShareLink(item: url) {
                        linkedInLabel(icon: "paperplane.fill", title: "Send", active: false)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                } else {
                    linkedInLabel(icon: "paperplane.fill", title: "Send", active: false)
                        .frame(maxWidth: .infinity)
                        .opacity(0.4)
                }
                linkedInAction(
                    icon: bookmarked ? "bookmark.fill" : "bookmark",
                    title: "Save",
                    active: bookmarked
                ) {
                    changeStatus(bookmarked ? .notWatched : .watchLater, item: item)
                }
            }
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.border).frame(height: 0.5)
            }
        }
    }

    private func linkedInAction(
        icon: String,
        title: String,
        active: Bool,
        activeColor: Color = PostReaderView.linkedInBlue,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            linkedInLabel(icon: icon, title: title, active: active, activeColor: activeColor)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private func linkedInLabel(
        icon: String,
        title: String,
        active: Bool,
        activeColor: Color = PostReaderView.linkedInBlue
    ) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 17))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(active ? activeColor : Theme.textSecondary)
        .frame(maxWidth: .infinity, minHeight: 48)
        .contentShape(Rectangle())
    }

    /// GitHub: Star (= Saved), Fork, plus Save and Share.
    private func gitHubActionBar(_ item: FeedItem) -> some View {
        let metrics = item.metrics
        let liked = status == .liked
        let bookmarked = status == .watchLater
        return HStack {
            barButton(
                icon: liked ? "star.fill" : "star",
                value: (metrics?.stars ?? 0) + (liked ? 1 : 0),
                color: liked ? Self.gitHubStar : Theme.textSecondary,
                label: liked ? "Remove from Saved" : "Star (save in My Feeds)"
            ) {
                changeStatus(liked ? .watched : .liked, item: item)
            }
            Spacer(minLength: 0)
            barButton(
                icon: "arrow.triangle.branch",
                value: metrics?.forks ?? 0,
                color: Theme.textSecondary,
                label: "Fork on GitHub"
            ) {
                if let raw = item.url { openExternal(raw) }
            }
            Spacer(minLength: 0)
            Button {
                changeStatus(bookmarked ? .notWatched : .watchLater, item: item)
            } label: {
                Image(systemName: bookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 16))
                    .foregroundStyle(bookmarked ? Self.xBlue : Theme.textSecondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(bookmarked ? "Remove from Read Later" : "Save (Read Later)")
            Spacer(minLength: 0)
            shareButton(item, color: Theme.textSecondary)
        }
        .padding(.horizontal, 4)
    }

    private func redditActionBar(_ item: FeedItem) -> some View {
        let metrics = item.metrics
        let upvoted = status == .liked
        let bookmarked = status == .watchLater
        return HStack(spacing: 8) {
            HStack(spacing: 0) {
                Button {
                    changeStatus(upvoted ? .watched : .liked, item: item)
                } label: {
                    Image(systemName: upvoted ? "arrowshape.up.fill" : "arrowshape.up")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel(upvoted ? "Remove upvote (Saved)" : "Upvote (save in My Feeds)")
                Text(Format.compactNumber((metrics?.score ?? 0) + (upvoted ? 1 : 0)))
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
                Button {
                    changeStatus(.watched, item: item)
                } label: {
                    Image(systemName: "arrowshape.down")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("Downvote (mark as read)")
            }
            .buttonStyle(.plain)
            .foregroundStyle(upvoted ? Color.white : Theme.textPrimary)
            .background(upvoted ? Self.redditOrange : Theme.input)
            .clipShape(Capsule())

            redditPill(icon: "bubble.left", text: Format.compactNumber(metrics?.comments ?? 0), color: Theme.textPrimary) {
                if let raw = item.url { openExternal(raw) }
            }
            .accessibilityLabel("Open comments on Reddit")

            redditPill(
                icon: bookmarked ? "bookmark.fill" : "bookmark",
                text: bookmarked ? "Saved" : "Save",
                color: bookmarked ? Self.xBlue : Theme.textPrimary
            ) {
                changeStatus(bookmarked ? .notWatched : .watchLater, item: item)
            }

            if let raw = item.url, let url = URL(string: raw) {
                ShareLink(item: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Share")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(Theme.input)
                    .clipShape(Capsule())
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func barButton(icon: String, value: Int, color: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(Format.compactNumber(value))
                    .font(.system(size: 13))
                    .monospacedDigit()
            }
            .foregroundStyle(color)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func redditPill(icon: String, text: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(text)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(Theme.input)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func shareButton(_ item: FeedItem, color: Color) -> some View {
        if let raw = item.url, let url = URL(string: raw) {
            ShareLink(item: url) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16))
                    .foregroundStyle(color)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Share")
        }
    }

    private func openExternal(_ raw: String) {
        if let url = URL(string: raw) { openURL(url) }
    }

    // MARK: - Behavior

    /// Downloaded items open from the copy on the phone (works offline, and the
    /// photos and episode don't download again). The status still comes from the
    /// server when there's a connection.
    private func load() async {
        if let saved = DownloadStore.shared.localItem(request.itemId) {
            item = saved
            status = router.pendingStatuses[saved.id] ?? saved.status
        }
        do {
            let loaded = try await SupabaseService.shared.fetchItem(id: request.itemId)
            if item == nil { item = loaded }
            status = router.pendingStatuses[loaded.id] ?? loaded.status
        } catch {
            if item == nil { loadFailed = true }
        }
    }

    /// Updates the feed right away through the router, then saves to Supabase.
    private func changeStatus(_ next: ItemStatus, item: FeedItem) {
        guard next != status else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        let previous = status
        status = next
        router.reportStatusChange(itemId: item.id, status: next)
        Task {
            do {
                try await SupabaseService.shared.updateItemStatus(id: item.id, status: next)
            } catch {
                status = previous
                router.reportStatusChange(itemId: item.id, status: previous)
                toasts.show("Couldn't update status", type: .error)
            }
            router.settleStatusChange(itemId: item.id)
        }
    }
}

/// Swipeable photos for Instagram and LinkedIn carousels, with page dots.
/// Carousel posts (Instagram, LinkedIn, X with several photos): every photo and
/// video in the post, swiped one at a time, with a "2 / 5" counter and dots.
/// The first video keeps the resume position (the same id web and Android use).
private struct MediaCarousel: View {
    let slides: [ItemMedia]
    let progressId: String?
    @State private var index = 0
    @State private var viewer: PhotoViewerRequest?

    private var firstVideoIndex: Int? { slides.firstIndex { $0.playableURL != nil } }

    /// The carousel's photos (videos have their own full screen button).
    private var photoURLs: [URL] {
        slides.compactMap { $0.playableURL == nil ? Self.photoURL($0.url) : nil }
    }

    /// Opens the full screen viewer on the photo at this carousel page.
    private func openPhoto(at offset: Int) {
        let photoIndex = slides[..<offset].filter { $0.playableURL == nil && Self.photoURL($0.url) != nil }.count
        viewer = PhotoViewerRequest(urls: photoURLs, index: photoIndex)
    }

    var body: some View {
        VStack(spacing: 8) {
            TabView(selection: $index) {
                ForEach(Array(slides.enumerated()), id: \.offset) { offset, slide in
                    page(slide, at: offset)
                        .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .aspectRatio(4 / 5, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(Color.black)
            .clipShape(.rect(cornerRadius: 12))
            .overlay(alignment: .topTrailing) {
                Text("\(index + 1) / \(slides.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.6))
                    .clipShape(Capsule())
                    .padding(10)
                    .allowsHitTesting(false)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(slides.count) photos and videos, showing \(index + 1)")

            HStack(spacing: 6) {
                ForEach(slides.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == index ? Theme.accent : Theme.textMuted.opacity(0.5))
                        .frame(width: i == index ? 16 : 6, height: 6)
                }
            }
            .animation(.easeOut(duration: 0.2), value: index)
            .accessibilityHidden(true)
        }
        .fullScreenCover(item: $viewer) { request in
            PhotoViewer(urls: request.urls, index: request.index)
        }
    }

    @ViewBuilder
    private func page(_ slide: ItemMedia, at offset: Int) -> some View {
        if let url = slide.playableURL {
            PostVideoPlayer(url: url, progressId: offset == firstVideoIndex ? progressId : nil)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let url = Self.photoURL(slide.url) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fit)
                } else {
                    Theme.card
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { openPhoto(at: offset) }
            .overlay(alignment: .topLeading) {
                ExpandButton { openPhoto(at: offset) }
            }
        } else {
            Color.black
        }
    }

    private static func photoURL(_ raw: String?) -> URL? {
        guard var raw, !raw.isEmpty else { return nil }
        if raw.hasPrefix("http://") { raw = "https://" + raw.dropFirst("http://".count) }
        return URL(string: raw)
    }
}

// MARK: - Full screen photos

private struct PhotoViewerRequest: Identifiable {
    let id = UUID()
    let urls: [URL]
    let index: Int
}

/// Top-left expand button on post photos, like the full screen button AVKit
/// shows on post videos.
private struct ExpandButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.black.opacity(0.6))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(10)
        .accessibilityLabel("Full screen")
    }
}

/// A post's single photo. Tapping it or the expand button opens it full screen.
private struct ExpandablePhoto: View {
    let url: URL
    @State private var showViewer = false

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().aspectRatio(contentMode: .fit)
            } else {
                Theme.card.aspectRatio(16 / 9, contentMode: .fit)
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(.rect(cornerRadius: 12))
        .contentShape(Rectangle())
        .onTapGesture { showViewer = true }
        .overlay(alignment: .topLeading) {
            ExpandButton { showViewer = true }
        }
        .fullScreenCover(isPresented: $showViewer) {
            PhotoViewer(urls: [url], index: 0)
        }
    }
}

/// Full screen photo viewer: swipe between the post's photos, pinch or
/// double-tap to zoom, × to close.
private struct PhotoViewer: View {
    let urls: [URL]
    @State var index: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(Array(urls.enumerated()), id: \.offset) { offset, url in
                    ZoomablePhoto(url: url)
                        .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: urls.count > 1 ? .always : .never))
            .ignoresSafeArea()

            HStack(spacing: 10) {
                if urls.count > 1 {
                    Text("\(index + 1) / \(urls.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6))
                        .clipShape(Capsule())
                }
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(16)
        }
        .statusBarHidden()
    }
}

private struct ZoomablePhoto: View {
    let url: URL
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().aspectRatio(contentMode: .fit)
            } else {
                ProgressView().tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scaleEffect(scale)
        .gesture(
            MagnifyGesture()
                .onChanged { value in scale = min(max(lastScale * value.magnification, 1), 4) }
                .onEnded { _ in lastScale = scale }
        )
        .onTapGesture(count: 2) {
            withAnimation(.easeOut(duration: 0.2)) {
                scale = scale > 1 ? 1 : 2
                lastScale = scale
            }
        }
    }
}

/// AVKit's own player view, inline. Unlike SwiftUI's VideoPlayer it has the
/// full screen button (and turns to landscape there), like the YouTube player.
private struct InlinePlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.exitsFullScreenWhenPlaybackEnds = false
        controller.videoGravity = .resizeAspect
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player { controller.player = player }
    }
}

private struct PhotoCarousel: View {
    let urls: [URL]

    var body: some View {
        TabView {
            ForEach(urls, id: \.self) { url in
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fit)
                    } else {
                        Theme.card
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .aspectRatio(4 / 5, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(.rect(cornerRadius: 12))
    }
}

/// Apple Music's embed player: previews for everyone, full songs for listeners
/// signed in to Apple Music. A single is a short strip, an album shows its tracks.
private struct AppleMusicEmbedPlayer: View {
    let url: URL
    let single: Bool

    var body: some View {
        EmbedWebView(url: url)
            .frame(height: single ? 175 : 450)
            .frame(maxWidth: .infinity)
            .clipShape(.rect(cornerRadius: 12))
    }
}

/// Plays a full podcast episode in place. The position is saved like a video's
/// (on this phone and in video_progress), so it resumes on any device, and
/// finishing the episode calls onFinished so it counts as watched.
private struct PodcastPlayerView: View {
    let url: URL
    let artwork: URL?
    let knownDuration: Int?
    let progressId: String
    let onFinished: () -> Void

    @Environment(VideoPrefs.self) private var prefs
    @Environment(\.scenePhase) private var scenePhase
    @State private var player: AVPlayer?
    @State private var tickTask: Task<Void, Never>?
    @State private var endObserver: NSObjectProtocol?
    @State private var time: Double = 0
    @State private var duration: Double = 0
    @State private var isPlaying = false
    @State private var isScrubbing = false
    @State private var speed: Float = 1
    @State private var clearedAtEnd = false

    private static let speeds: [Float] = [1, 1.25, 1.5, 2]

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                AsyncImage(url: artwork) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Theme.input
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(.rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text((totalLength > 0 ? "\(Self.clock(totalLength)) long" : "Full episode") + (url.isFileURL ? " · Downloaded" : ""))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                    Button {
                        togglePlay()
                    } label: {
                        Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 40)
                            .background(Capsule().fill(Theme.accent))
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }

            VStack(spacing: 4) {
                Slider(
                    value: Binding(get: { time }, set: { time = $0 }),
                    in: 0...max(totalLength, 1),
                    onEditingChanged: { editing in
                        isScrubbing = editing
                        if !editing { seek(to: time) }
                    }
                )
                .tint(Theme.accent)
                .accessibilityLabel("Episode position")
                HStack {
                    Text(Self.clock(time))
                    Spacer()
                    Text("-" + Self.clock(max(totalLength - time, 0)))
                }
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
            }

            HStack(spacing: 8) {
                controlButton("Back 15s", systemImage: "gobackward.15") { skip(-15) }
                controlButton("Forward 30s", systemImage: "goforward.30") { skip(30) }
                Button {
                    let next = Self.speeds[((Self.speeds.firstIndex(of: speed) ?? 0) + 1) % Self.speeds.count]
                    speed = next
                    if isPlaying { player?.rate = next }
                } label: {
                    Text(speed == 1 ? "1×" : String(format: "%g×", speed))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(minWidth: 52, minHeight: 40)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Playback speed \(String(format: "%g", speed)) times")
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
        .onAppear(perform: start)
        .onDisappear(perform: stop)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { persistPosition() }
        }
    }

    private var totalLength: Double {
        duration > 0 ? duration : Double(knownDuration ?? 0)
    }

    private func controlButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(minWidth: 52, minHeight: 40)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func start() {
        guard player == nil else { return }
        // Plays with the silent switch on, like any podcast app.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        let newPlayer = AVPlayer(url: url)
        player = newPlayer
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: newPlayer.currentItem,
            queue: .main
        ) { _ in
            Task { @MainActor in finished() }
        }
        resume(newPlayer)
        tickTask = tick(newPlayer)
    }

    private func stop() {
        player?.pause()
        persistPosition()
        tickTask?.cancel()
        tickTask = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
    }

    private func togglePlay() {
        guard let player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
            persistPosition()
        } else {
            try? AVAudioSession.sharedInstance().setActive(true)
            player.playImmediately(atRate: speed)
        }
    }

    private func skip(_ delta: Double) {
        seek(to: min(max(time + delta, 0), totalLength > 0 ? totalLength : time + delta))
    }

    private func seek(to seconds: Double) {
        time = seconds
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }

    private func finished() {
        isPlaying = false
        time = 0
        prefs.clearPosition(videoId: progressId)
        Task { try? await SupabaseService.shared.deleteVideoProgress(videoId: progressId) }
        clearedAtEnd = true
        player?.seek(to: .zero)
        onFinished()
    }

    /// Twice a second: refreshes the time and play state, and saves every 5 s
    /// while playing and right after a pause.
    private func tick(_ player: AVPlayer) -> Task<Void, Never> {
        Task {
            var wasPlaying = false
            var ticksSinceSave = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                let playing = player.timeControlStatus == .playing
                isPlaying = playing
                if let length = player.currentItem?.duration.seconds, length.isFinite, length > 0 {
                    duration = length
                }
                if !isScrubbing {
                    let now = player.currentTime().seconds
                    if now.isFinite { time = now }
                }
                if playing {
                    ticksSinceSave += 1
                    if ticksSinceSave >= 10 {
                        ticksSinceSave = 0
                        persistPosition()
                    }
                } else if wasPlaying {
                    persistPosition()
                }
                wasPlaying = playing
            }
        }
    }

    private func persistPosition() {
        guard let player, let item = player.currentItem else { return }
        let position = player.currentTime().seconds
        let length = item.duration.seconds.isFinite ? item.duration.seconds : totalLength
        guard position.isFinite, length > 0, position > 0 else { return }
        if VideoProgress.isNearEnd(position: position, duration: length) {
            if !clearedAtEnd {
                clearedAtEnd = true
                prefs.clearPosition(videoId: progressId)
                Task { try? await SupabaseService.shared.deleteVideoProgress(videoId: progressId) }
            }
            return
        }
        clearedAtEnd = false
        let now = Date()
        prefs.savePosition(videoId: progressId, time: position, duration: length, updatedAt: now)
        Task {
            try? await SupabaseService.shared.saveVideoProgress(
                videoId: progressId,
                position: position,
                duration: length,
                updatedAt: now
            )
        }
    }

    /// Starts from where the listener stopped, using whichever copy is newer:
    /// this phone's or the shared one (saved on the web or Android).
    private func resume(_ player: AVPlayer) {
        let local = prefs.savedPosition(videoId: progressId)
        Task {
            var position = local?.time
            var length = local?.duration
            if let remote = try? await SupabaseService.shared.fetchVideoProgress(videoId: progressId),
               remote.updatedAt > (local?.updatedAt ?? .distantPast) {
                position = remote.position
                length = remote.duration
                prefs.savePosition(videoId: progressId, time: remote.position, duration: remote.duration, updatedAt: remote.updatedAt)
            }
            guard let position, let length,
                  let resumeAt = VideoProgress.resumeTime(position: position, duration: length) else { return }
            for _ in 0..<50 {
                if player.currentItem?.status == .readyToPlay { break }
                try? await Task.sleep(for: .milliseconds(200))
            }
            guard player.currentTime().seconds < 1 else { return }
            _ = await player.seek(to: CMTime(seconds: resumeAt, preferredTimescale: 600))
            time = resumeAt
        }
    }

    static func clock(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }
}

/// Facebook's official video embed player. Reels are 9:16, other videos 16:9.
/// Plays through Facebook's own player, since Facebook's direct MP4 links expire.
private struct FacebookEmbedPlayer: View {
    let url: URL
    let portrait: Bool

    /// Embed URL for a Facebook post link; reel links become watch links,
    /// which the embed player understands.
    static func embed(for postURL: String?) -> (url: URL, portrait: Bool)? {
        guard let postURL, postURL.range(of: "facebook.com/", options: .caseInsensitive) != nil else { return nil }
        var href = postURL
        var portrait = false
        if let match = postURL.range(of: #"facebook\.com/reel/(\d+)"#, options: [.regularExpression, .caseInsensitive]) {
            let digits = postURL[match].split(separator: "/").last.map(String.init) ?? ""
            if !digits.isEmpty {
                href = "https://www.facebook.com/watch/?v=\(digits)"
                portrait = true
            }
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.facebook.com"
        components.path = "/plugins/video.php"
        components.queryItems = [
            URLQueryItem(name: "href", value: href),
            URLQueryItem(name: "show_text", value: "false"),
            URLQueryItem(name: "autoplay", value: "false"),
        ]
        guard let url = components.url else { return nil }
        return (url, portrait)
    }

    var body: some View {
        EmbedWebView(url: url)
            .aspectRatio(portrait ? 9 / 16 : 16 / 9, contentMode: .fit)
            .frame(maxWidth: portrait ? 380 : .infinity)
            .background(Color.black)
            .clipShape(.rect(cornerRadius: 12))
            .frame(maxWidth: .infinity)
    }
}

/// A web view that loads one embed page, used by the Facebook player.
private struct EmbedWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: ()) {
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
    }
}

/// TikTok's official embed player, 9:16 like on TikTok. Plays the original
/// upload in TikTok's own player, since TikTok's direct video links expire.
private struct TikTokEmbedPlayer: View {
    let videoId: String

    var body: some View {
        TikTokEmbedWebView(videoId: videoId)
            .aspectRatio(9 / 16, contentMode: .fit)
            .frame(maxWidth: 380)
            .background(Color.black)
            .clipShape(.rect(cornerRadius: 12))
            .frame(maxWidth: .infinity)
    }
}

private struct TikTokEmbedWebView: UIViewRepresentable {
    let videoId: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        if let url = Self.playerURL(videoId) { webView.load(URLRequest(url: url)) }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: ()) {
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
    }

    private static func playerURL(_ videoId: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.tiktok.com"
        components.path = "/player/v1/\(videoId)"
        components.queryItems = [
            URLQueryItem(name: "music_info", value: "1"),
            URLQueryItem(name: "description", value: "0"),
            URLQueryItem(name: "rel", value: "0"),
            URLQueryItem(name: "native_context_menu", value: "0"),
        ]
        return components.url
    }
}

/// Plays a post's video in place, like on X and Reddit. The player is created
/// when the view appears and paused when it goes away.
/// With a progressId (the item's video_id, e.g. "x:123") it resumes like YouTube
/// videos: the position is saved every 5 s while playing, on pause, when the post
/// closes and when the app goes to the background, on this phone and in the shared
/// video_progress table, so web and Android pick up from the same spot.
private struct PostVideoPlayer: View {
    let url: URL
    var progressId: String? = nil

    @Environment(VideoPrefs.self) private var prefs
    @Environment(\.scenePhase) private var scenePhase
    @State private var player: AVPlayer?
    @State private var trackTask: Task<Void, Never>?
    @State private var clearedAtEnd = false

    var body: some View {
        ZStack {
            Color.black
            if let player {
                InlinePlayerView(player: player)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(.rect(cornerRadius: 12))
        .onAppear {
            if player == nil {
                let newPlayer = AVPlayer(url: url)
                player = newPlayer
                resume(newPlayer)
            }
            if trackTask == nil, let player { trackTask = track(player) }
        }
        .onDisappear {
            player?.pause()
            trackTask?.cancel()
            trackTask = nil
            persistPosition()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { persistPosition() }
        }
    }

    /// Checks once a second: saves every 5 s while playing, and right after a pause.
    private func track(_ player: AVPlayer) -> Task<Void, Never> {
        Task {
            var wasPlaying = false
            var secondsSinceSave = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                let playing = player.timeControlStatus == .playing
                if playing {
                    secondsSinceSave += 1
                    if secondsSinceSave >= 5 {
                        secondsSinceSave = 0
                        persistPosition()
                    }
                } else if wasPlaying {
                    persistPosition()
                }
                wasPlaying = playing
            }
        }
    }

    private func persistPosition() {
        guard let progressId, let player, let item = player.currentItem else { return }
        let time = player.currentTime().seconds
        let duration = item.duration.seconds
        guard time.isFinite, duration.isFinite, duration > 0, time > 0 else { return }
        if VideoProgress.isNearEnd(position: time, duration: duration) {
            // Finished: forget it here and everywhere, so it starts over next time.
            if !clearedAtEnd {
                clearedAtEnd = true
                prefs.clearPosition(videoId: progressId)
                Task { try? await SupabaseService.shared.deleteVideoProgress(videoId: progressId) }
            }
            return
        }
        clearedAtEnd = false
        let now = Date()
        prefs.savePosition(videoId: progressId, time: time, duration: duration, updatedAt: now)
        Task {
            try? await SupabaseService.shared.saveVideoProgress(
                videoId: progressId,
                position: time,
                duration: duration,
                updatedAt: now
            )
        }
    }

    /// Seeks to where the user stopped, using whichever copy is newer: this
    /// phone's or the shared one (saved on the web or Android).
    private func resume(_ player: AVPlayer) {
        guard let progressId else { return }
        let local = prefs.savedPosition(videoId: progressId)
        Task {
            var position = local?.time
            var duration = local?.duration
            if let remote = try? await SupabaseService.shared.fetchVideoProgress(videoId: progressId),
               remote.updatedAt > (local?.updatedAt ?? .distantPast) {
                position = remote.position
                duration = remote.duration
                prefs.savePosition(videoId: progressId, time: remote.position, duration: remote.duration, updatedAt: remote.updatedAt)
            }
            guard let position, let duration,
                  let resumeAt = VideoProgress.resumeTime(position: position, duration: duration) else { return }
            // Wait for the video to load (up to 10 s) before seeking.
            for _ in 0..<50 {
                if player.currentItem?.status == .readyToPlay { break }
                try? await Task.sleep(for: .milliseconds(200))
            }
            // Only jump if the user hasn't already moved.
            guard player.currentTime().seconds < 1 else { return }
            _ = await player.seek(to: CMTime(seconds: resumeAt, preferredTimescale: 600))
        }
    }
}
