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

    /// Posts are read, not watched: same four statuses, reading-friendly labels.
    private struct StatusOption: Hashable {
        let status: ItemStatus
        let label: String
    }

    private static let statuses: [StatusOption] = [
        StatusOption(status: .notWatched, label: "Unread"),
        StatusOption(status: .watched, label: "Read"),
        StatusOption(status: .liked, label: "Saved"),
        StatusOption(status: .watchLater, label: "Read Later"),
    ]

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

                    if let imageURL = item.postImageURL {
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

                    metricsRow(item, platform: platform)

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

    private func metricsRow(_ item: FeedItem, platform: SourcePlatform) -> some View {
        let metrics = item.metrics
        return HStack(spacing: 18) {
            if platform == .x {
                metric(icon: "bubble.left", value: Format.compactNumber(metrics?.replies ?? 0))
                metric(icon: "arrow.2.squarepath", value: Format.compactNumber(metrics?.reposts ?? 0))
                metric(icon: "hand.thumbsup", value: Format.compactNumber(metrics?.likes ?? 0))
                if let views = metrics?.views, views > 0 {
                    metric(icon: "eye", value: Format.compactNumber(views))
                }
            } else {
                metric(icon: "arrow.up", value: Format.compactNumber(metrics?.score ?? 0))
                metric(icon: "bubble.left", value: "\(Format.compactNumber(metrics?.comments ?? 0)) comments")
            }
            Spacer(minLength: 0)
        }
    }

    private func metric(icon: String, value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13))
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(Theme.textSecondary)
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
            HStack(spacing: 6) {
                ForEach(Self.statuses, id: \.status) { entry in
                    let active = status == entry.status
                    Button {
                        changeStatus(entry.status, item: item)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: entry.status.icon)
                                .font(.system(size: 15))
                                .foregroundStyle(entry.status.color)
                            Text(entry.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(active ? Theme.accent.opacity(0.10) : Color.clear)
                        .clipShape(.rect(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(active ? Theme.accent : Theme.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(active ? .isSelected : [])
                }
            }

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
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Theme.card)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.border).frame(height: 0.5)
        }
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
