import SwiftUI

struct FeedView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toasts

    @State private var items: [FeedItem] = []
    @State private var agents: [Agent] = []
    @State private var channels: [Channel] = []
    @State private var isLoading = true

    // Filters
    @State private var search = ""
    @State private var agentFilter: String? = nil
    @State private var channelFilter: String? = nil
    @State private var statusFilter: ItemStatus? = .notWatched
    @State private var sortMode: SortMode = .recent

    // Selection
    @State private var selectedIds: Set<String> = []
    @State private var isBulkUpdating = false

    // Modals
    @State private var activeFilterModal: FilterModal?
    @State private var statusModalItem: FeedItem?
    @State private var showBulkStatusModal = false

    enum SortMode: String, CaseIterable {
        case recent = "Recent"
        case views = "Views"
        case ranked = "Ranking"
    }

    enum FilterModal { case agent, channel, status, sort }

    private var sortedAgents: [Agent] {
        agents.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var filteredItems: [FeedItem] {
        var result = items
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            result = result.filter { item in
                (item.title?.lowercased().contains(query) ?? false)
                || (item.channelName?.lowercased().contains(query) ?? false)
                || (item.analysis?.shortSummary?.lowercased().contains(query) ?? false)
                || (item.analysis?.tags?.contains { $0.lowercased().contains(query) } ?? false)
            }
        }
        if let agentFilter {
            result = result.filter { $0.agentId == agentFilter }
        }
        if let channelFilter {
            result = result.filter { $0.channelId == channelFilter }
        }
        if let statusFilter {
            result = result.filter { $0.status == statusFilter }
        }
        switch sortMode {
        case .recent:
            break
        case .views:
            result = result.sorted { ($0.analysis?.viewsAtAnalysis ?? 0) > ($1.analysis?.viewsAtAnalysis ?? 0) }
        case .ranked:
            result = result.sorted { ($0.analysis?.rankingScore ?? 0) > ($1.analysis?.rankingScore ?? 0) }
        }
        return result
    }

    /// Channels for the selected agent (deduped by channel_id).
    private var agentChannels: [Channel] {
        guard let agentFilter else { return [] }
        var seen = Set<String>()
        return channels.filter { $0.agentId == agentFilter }.filter { channel in
            guard let cid = channel.channelId else { return false }
            return seen.insert(cid).inserted
        }
    }

    private func channelItemCount(_ channelId: String?) -> Int {
        guard let channelId else { return items.count }
        return items.filter { $0.channelId == channelId }.count
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                if !selectedIds.isEmpty { bulkBar }
                searchBar
                filterStack
                list
            }
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)

            filterModalOverlay
            statusModalOverlay
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
        .onChange(of: router.feedRequest) { _, request in
            guard let request else { return }
            agentFilter = request.agentId
            channelFilter = nil
            if let status = request.status { statusFilter = status }
            router.feedRequest = nil
        }
        .onAppear {
            if let request = router.feedRequest {
                agentFilter = request.agentId
                channelFilter = nil
                if let status = request.status { statusFilter = status }
                router.feedRequest = nil
            }
        }
        .onChange(of: router.lastStatusChange) { _, change in
            // Status set from the player: apply it right away so the video
            // leaves the list without waiting for the reload below.
            guard let change,
                  let index = items.firstIndex(where: { $0.id == change.itemId }) else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                items[index].userStatus = change.status
            }
        }
        .onChange(of: router.playerRequest == nil) { wasClosed, isClosed in
            if !wasClosed && isClosed {
                Task { await load() }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Research Feed")
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            if !isLoading {
                Text("\(filteredItems.count) videos")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var bulkBar: some View {
        HStack {
            Text("\(selectedIds.count) selected")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Button {
                showBulkStatusModal = true
            } label: {
                HStack(spacing: 6) {
                    if isBulkUpdating {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Text("Set status")
                            .font(.system(size: 14, weight: .bold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(minWidth: 126, minHeight: 40)
                .background(Theme.accent)
                .clipShape(.rect(cornerRadius: 10))
                .opacity(selectedIds.isEmpty ? 0.4 : 1)
            }
            .disabled(selectedIds.isEmpty || isBulkUpdating)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(Theme.textMuted)
            TextField("Search videos, channels, tags...", text: $search)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    ZStack {
                        Circle().fill(Theme.border).frame(width: 24, height: 24)
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.textMuted)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Theme.input)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var filterStack: some View {
        VStack(spacing: 8) {
            filterTrigger(
                icon: "cpu",
                label: agentFilter.flatMap { id in agents.first { $0.id == id }?.name } ?? "All Agents",
                badge: nil
            ) { activeFilterModal = .agent }

            if !agentChannels.isEmpty {
                filterTrigger(
                    icon: "dot.radiowaves.left.and.right",
                    label: channelFilter.flatMap { id in agentChannels.first { $0.channelId == id }?.displayName } ?? "All Channels",
                    badge: "\(channelItemCount(channelFilter))"
                ) { activeFilterModal = .channel }
            }

            HStack(spacing: 8) {
                filterTrigger(
                    icon: "line.3.horizontal.decrease",
                    label: statusFilter?.label ?? "All Statuses",
                    badge: nil
                ) { activeFilterModal = .status }

                filterTrigger(
                    icon: "arrow.up.arrow.down",
                    label: sortMode.rawValue,
                    badge: nil
                ) { activeFilterModal = .sort }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func filterTrigger(icon: String, label: String, badge: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    if let badge {
                        Text(badge)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.textMuted)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Theme.input)
                            .clipShape(.rect(cornerRadius: 8))
                    }
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
            }
            .padding(12)
            .background(Theme.card)
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .tint(Theme.accent)
                        .padding(.vertical, 60)
                } else if filteredItems.isEmpty {
                    emptyState
                } else {
                    ForEach(filteredItems) { item in
                        FeedItemCard(
                            item: item,
                            isSelected: selectedIds.contains(item.id),
                            onTap: {
                                if let videoId = item.resolvedVideoId {
                                    router.openVideo(videoId: videoId, itemId: item.id)
                                }
                            },
                            onSelectionTap: { toggleSelection(item) },
                            onStatusTap: { statusModalItem = item }
                        )
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 32)
        }
        .refreshable { await load() }
    }

    private var emptyState: some View {
        let hasFilters = !search.isEmpty || agentFilter != nil || channelFilter != nil || statusFilter != .notWatched
        return VStack(spacing: 6) {
            Text(hasFilters ? "No videos match your filters" : "No videos yet")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(hasFilters ? "Try adjusting your search or filters." : "Run an agent to start discovering videos.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .cardStyle(radius: 12)
    }

    // MARK: - Modals

    @ViewBuilder
    private var filterModalOverlay: some View {
        if let modal = activeFilterModal {
            switch modal {
            case .agent:
                PickerModal(title: "Agent", onDismiss: { activeFilterModal = nil }) {
                    PickerRow(label: "All Agents", isActive: agentFilter == nil) {
                        agentFilter = nil
                        channelFilter = nil
                        activeFilterModal = nil
                    }
                    ForEach(sortedAgents) { agent in
                        PickerRow(label: agent.name, isActive: agentFilter == agent.id) {
                            agentFilter = agent.id
                            channelFilter = nil
                            activeFilterModal = nil
                        }
                    }
                }
            case .channel:
                PickerModal(title: "Channel", onDismiss: { activeFilterModal = nil }) {
                    PickerRow(label: "All Channels", isActive: channelFilter == nil, badge: "\(items.count)") {
                        channelFilter = nil
                        activeFilterModal = nil
                    }
                    ForEach(agentChannels) { channel in
                        PickerRow(
                            label: channel.displayName,
                            isActive: channelFilter == channel.channelId,
                            badge: "\(channelItemCount(channel.channelId))"
                        ) {
                            channelFilter = channel.channelId
                            activeFilterModal = nil
                        }
                    }
                }
            case .status:
                PickerModal(title: "Status", onDismiss: { activeFilterModal = nil }) {
                    PickerRow(label: "All Statuses", isActive: statusFilter == nil) {
                        statusFilter = nil
                        activeFilterModal = nil
                    }
                    ForEach(ItemStatus.allCases, id: \.self) { status in
                        PickerRow(
                            label: status.label,
                            isActive: statusFilter == status,
                            iconName: status.icon,
                            iconColor: status.color
                        ) {
                            statusFilter = status
                            activeFilterModal = nil
                        }
                    }
                }
            case .sort:
                PickerModal(title: "Sort", onDismiss: { activeFilterModal = nil }) {
                    ForEach(SortMode.allCases, id: \.self) { mode in
                        PickerRow(label: mode.rawValue, isActive: sortMode == mode) {
                            sortMode = mode
                            activeFilterModal = nil
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statusModalOverlay: some View {
        if let item = statusModalItem {
            PickerModal(title: "Set Status", onDismiss: { statusModalItem = nil }) {
                ForEach(ItemStatus.allCases, id: \.self) { status in
                    PickerRow(
                        label: status.label,
                        isActive: item.status == status,
                        iconName: status.icon,
                        iconColor: status.color
                    ) {
                        statusModalItem = nil
                        updateStatus(item: item, status: status)
                    }
                }
            }
        } else if showBulkStatusModal {
            PickerModal(title: "Set status for \(selectedIds.count) videos", onDismiss: { showBulkStatusModal = false }) {
                ForEach(ItemStatus.allCases, id: \.self) { status in
                    PickerRow(label: status.label, showCheck: false, iconName: status.icon, iconColor: status.color) {
                        showBulkStatusModal = false
                        bulkUpdateStatus(status)
                    }
                }
            }
        }
    }

    // MARK: - Data & mutations

    private func load() async {
        let service = SupabaseService.shared
        isLoading = items.isEmpty

        // Feed items are the primary content on this screen. Load them
        // independently so a failure in optional agent/channel metadata never
        // leaves the iOS feed blank.
        do {
            var fetched = try await service.fetchFeedItems(limit: 500)
            // Keep statuses that are still being saved, so the reload can't
            // bring a just-watched video back for a moment.
            if !router.pendingStatuses.isEmpty {
                for index in fetched.indices {
                    if let pending = router.pendingStatuses[fetched[index].id] {
                        fetched[index].userStatus = pending
                    }
                }
            }
            items = fetched
        } catch {
            toasts.show("Couldn't load videos: \(error.localizedDescription)", type: .error)
        }

        // These values only enhance filter labels and channel choices. Keep
        // rendering videos even if either request fails or contains bad data.
        async let loadedAgents = try? service.fetchAgents()
        async let loadedChannels = try? service.fetchAllChannels()
        let (agentResult, channelResult) = await (loadedAgents, loadedChannels)
        if let agentResult { agents = agentResult }
        if let channelResult { channels = channelResult }

        isLoading = false
    }

    private func toggleSelection(_ item: FeedItem) {
        if selectedIds.contains(item.id) {
            selectedIds.remove(item.id)
        } else {
            selectedIds.insert(item.id)
        }
    }

    private func updateStatus(item: FeedItem, status: ItemStatus) {
        UISelectionFeedbackGenerator().selectionChanged()
        let previous = item.userStatus
        // Optimistic update
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].userStatus = status
        }
        Task {
            do {
                try await SupabaseService.shared.updateItemStatus(id: item.id, status: status)
            } catch {
                if let index = items.firstIndex(where: { $0.id == item.id }) {
                    items[index].userStatus = previous
                }
                toasts.show("Couldn't update status", type: .error)
            }
        }
    }

    private func bulkUpdateStatus(_ status: ItemStatus) {
        let ids = Array(selectedIds)
        guard !ids.isEmpty else { return }
        isBulkUpdating = true
        // Optimistic update
        let snapshot = items
        for index in items.indices where selectedIds.contains(items[index].id) {
            items[index].userStatus = status
        }
        Task {
            do {
                try await SupabaseService.shared.bulkUpdateItemStatus(ids: ids, status: status)
                toasts.show("Updated \(ids.count) video\(ids.count == 1 ? "" : "s")")
                selectedIds.removeAll()
            } catch {
                items = snapshot
                toasts.show("Couldn't update selected videos", type: .error)
            }
            isBulkUpdating = false
        }
    }
}

// MARK: - Feed item card

private struct FeedItemCard: View {
    let item: FeedItem
    let isSelected: Bool
    let onTap: () -> Void
    let onSelectionTap: () -> Void
    let onStatusTap: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 0) {
                    thumbnail
                    body12
                }
                .background(Theme.card)
                .clipShape(.rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Theme.accent : Theme.border, lineWidth: isSelected ? 2 : 0.5)
                )
            }
            .buttonStyle(.plain)

            Button(action: onSelectionTap) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isSelected ? Theme.accent : Theme.card)
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Theme.accent, lineWidth: 2)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(12)
            .accessibilityLabel(isSelected ? "Deselect video" : "Select video")
        }
    }

    private var thumbnail: some View {
        Color(Theme.input)
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                if !thumbnailCandidates.isEmpty {
                    FeedThumbnailImage(candidates: thumbnailCandidates)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                ZStack {
                    Color.black.opacity(0.15)
                    Image(systemName: "play.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                }
                .allowsHitTesting(false)
            }
            .clipped()
    }

    /// Stored thumbnail first (forced to https), then YouTube's standard
    /// sizes as fallbacks for rows whose stored URL is missing or broken.
    private var thumbnailCandidates: [URL] {
        var urls: [URL] = []
        if var raw = item.thumbnailUrl, !raw.isEmpty {
            if raw.hasPrefix("http://") { raw = "https://" + raw.dropFirst("http://".count) }
            if let url = URL(string: raw) { urls.append(url) }
        }
        if let videoId = item.resolvedVideoId {
            for size in ["hqdefault", "mqdefault"] {
                if let url = URL(string: "https://i.ytimg.com/vi/\(videoId)/\(size).jpg"), !urls.contains(url) {
                    urls.append(url)
                }
            }
        }
        return urls
    }

    private var body12: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 6) {
                Text(item.title ?? "Untitled")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onStatusTap) {
                    HStack(spacing: 4) {
                        Image(systemName: item.status.icon)
                            .font(.system(size: 13))
                            .foregroundStyle(item.status.color)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Theme.input)
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.border, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }

            HStack {
                HStack(spacing: 6) {
                    ZStack {
                        Circle().fill(Theme.input).frame(width: 24, height: 24)
                        Circle().stroke(Theme.border, lineWidth: 0.5).frame(width: 24, height: 24)
                        Text(String((item.channelName ?? "?").prefix(1)).uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Text("\(item.channelName ?? "Unknown channel") · \(Format.timeAgo(item.publishedAt))")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(Format.duration(item.displayDurationSeconds))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                    .monospacedDigit()
            }
            .padding(.top, 8)

            if let summary = item.analysis?.shortSummary, !summary.isEmpty {
                Text(summary)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .lineSpacing(4)
                    .padding(.top, 10)
            }

            if let tags = item.analysis?.tags, !tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tags.prefix(4), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.input)
                            .clipShape(.rect(cornerRadius: 6))
                            .lineLimit(1)
                    }
                }
                .padding(.top, 10)
            }

            HStack(spacing: 16) {
                statChip(icon: "eye", value: item.displayViews)
                statChip(icon: "hand.thumbsup", value: item.displayLikes)
                statChip(icon: "bubble.left", value: item.displayComments)
                Spacer()
            }
            .padding(.top, 10)
        }
        .padding(12)
    }

    private func statChip(icon: String, value: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(Format.compactNumber(value))
                .font(.system(size: 12))
                .monospacedDigit()
        }
        .foregroundStyle(Theme.textMuted)
    }
}

// MARK: - Thumbnails

/// Shared thumbnail cache. AsyncImage has no cache and, inside a LazyVStack,
/// gives up for good when its load is cancelled mid-scroll, which left cards
/// showing only the title and details.
private final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let memory = NSCache<NSURL, UIImage>()
    private let session: URLSession

    private init() {
        memory.countLimit = 400
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(memoryCapacity: 20 * 1024 * 1024, diskCapacity: 150 * 1024 * 1024)
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)
    }

    func cached(_ url: URL) -> UIImage? {
        memory.object(forKey: url as NSURL)
    }

    func load(_ url: URL) async -> UIImage? {
        if let image = cached(url) { return image }
        guard let result = try? await session.data(from: url),
              let http = result.1 as? HTTPURLResponse, http.statusCode == 200,
              let image = UIImage(data: result.0) else { return nil }
        memory.setObject(image, forKey: url as NSURL)
        return image
    }
}

/// Loads a card thumbnail through ThumbnailCache, trying each candidate URL
/// and retrying once. The load restarts whenever the card scrolls back on
/// screen, and cached images show instantly.
private struct FeedThumbnailImage: View {
    let candidates: [URL]
    @State private var image: UIImage?

    init(candidates: [URL]) {
        self.candidates = candidates
        _image = State(initialValue: candidates.lazy.compactMap { ThumbnailCache.shared.cached($0) }.first)
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            }
        }
        .task(id: candidates) { await load() }
    }

    private func load() async {
        if image != nil { return }
        for attempt in 0..<2 {
            for url in candidates {
                if Task.isCancelled { return }
                if let loaded = await ThumbnailCache.shared.load(url) {
                    withAnimation(.easeIn(duration: 0.15)) { image = loaded }
                    return
                }
            }
            if attempt == 0 { try? await Task.sleep(for: .milliseconds(700)) }
        }
    }
}
