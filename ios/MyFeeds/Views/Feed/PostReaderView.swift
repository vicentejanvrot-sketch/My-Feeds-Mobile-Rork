import AVKit
import SwiftUI

/// In-app reader for X posts and Reddit threads. The native twin of the web
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

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let item {
                content(item)
            } else if loadFailed {
                VStack(spacing: 12) {
                    Text("Couldn't load this post.")
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
                            .font(.system(size: platform == .x ? 17 : 15))
                            .foregroundStyle(Theme.textPrimary)
                            .lineSpacing(platform == .x ? 6 : 5)
                            .textSelection(.enabled)
                    } else if platform == .x, let title = item.title {
                        Text(title)
                            .font(.system(size: 17))
                            .foregroundStyle(Theme.textPrimary)
                            .lineSpacing(6)
                            .textSelection(.enabled)
                    }

                    if let video = item.postVideo, let url = video.playableURL {
                        PostVideoPlayer(url: url)
                    } else if let imageURL = item.postImageURL {
                        AsyncImage(url: imageURL) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fit)
                            } else {
                                Theme.card.aspectRatio(16 / 9, contentMode: .fit)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .clipShape(.rect(cornerRadius: 12))
                    }

                    if let quote = item.quoteEmbed {
                        quoteCard(quote)
                    }

                    summaryBox(item, platform: platform)

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
    private func xDateLine(_ item: FeedItem) -> Text? {
        guard let raw = item.publishedAt else { return nil }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = parser.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "h:mm a · MMM d, yyyy"
        var line = Text(formatter.string(from: date)).foregroundColor(Theme.textSecondary)
        if let views = item.metrics?.views, views > 0 {
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

    private func footer(_ item: FeedItem, platform: SourcePlatform) -> some View {
        VStack(spacing: 10) {
            if platform == .x {
                if let line = xDateLine(item) {
                    line
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
                xActionBar(item)
            } else {
                redditActionBar(item)
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

    private func load() async {
        do {
            let loaded = try await SupabaseService.shared.fetchItem(id: request.itemId)
            item = loaded
            status = router.pendingStatuses[loaded.id] ?? loaded.status
        } catch {
            loadFailed = true
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

/// Plays a post's video in place, like on X and Reddit. The player is created
/// when the view appears and paused when it goes away.
private struct PostVideoPlayer: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black
            if let player {
                VideoPlayer(player: player)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(.rect(cornerRadius: 12))
        .onAppear {
            if player == nil { player = AVPlayer(url: url) }
        }
        .onDisappear { player?.pause() }
    }
}
