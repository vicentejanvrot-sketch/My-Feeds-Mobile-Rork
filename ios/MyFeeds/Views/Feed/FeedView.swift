import AVFoundation
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
    @State private var platformFilter: SourcePlatform? = nil
    @State private var sortMode: SortMode = .priority

    // Selection
    @State private var selectedIds: Set<String> = []
    @State private var isBulkUpdating = false

    // Modals
    @State private var activeFilterModal: FilterModal?
    @State private var statusModalItem: FeedItem?
    @State private var showBulkStatusModal = false

    enum SortMode: String, CaseIterable {
        case priority = "Priority"
        case recent = "Recent"
        case views = "Views"
    }

    enum FilterModal { case agent, channel, status, sort }

    private var sortedAgents: [Agent] {
        agents.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // Counts work like the web feed: each number matches what the feed shows
    // after picking that option, under the other filters currently applied.

    /// Search, agent and status filters. The channel counts come from this list.
    private var statusSearchItems: [FeedItem] {
        var result = items
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            result = result.filter { item in
                (item.title?.lowercased().contains(query) ?? false)
                || (item.channelName?.lowercased().contains(query) ?? false)
                || (item.body?.lowercased().contains(query) ?? false)
                || (item.analysis?.shortSummary?.lowercased().contains(query) ?? false)
                || (item.analysis?.tags?.contains { $0.lowercased().contains(query) } ?? false)
            }
        }
        if let agentFilter {
            result = result.filter { $0.agentId == agentFilter }
        }
        result = Self.dedupedByVideo(result)
        if let statusFilter {
            result = result.filter { $0.status == statusFilter }
        }
        return result
    }

    /// The same video or post can be saved under more than one agent: show it
    /// once. Keeps the first (newest) copy, or the copy already marked (liked,
    /// watch later, watched), so a leftover not-watched copy can't bring it back.
    /// Same rule as the web and Android apps.
    private static func dedupedByVideo(_ items: [FeedItem]) -> [FeedItem] {
        func rank(_ status: ItemStatus) -> Int {
            switch status {
            case .liked: return 3
            case .watchLater: return 2
            case .watched: return 1
            case .notWatched: return 0
            }
        }
        var position: [String: Int] = [:]
        var result: [FeedItem] = []
        result.reserveCapacity(items.count)
        for item in items {
            guard let key = item.videoId, !key.isEmpty else {
                result.append(item)
                continue
            }
            if let at = position[key] {
                if rank(item.status) > rank(result[at].status) { result[at] = item }
            } else {
                position[key] = result.count
                result.append(item)
            }
        }
        return result
    }

    /// Every filter except the platform chips. The chip counts come from this list.
    private var baseFilteredItems: [FeedItem] {
        guard let channelFilter else { return statusSearchItems }
        return statusSearchItems.filter { $0.channelId == channelFilter }
    }

    /// Each enabled source's Priority (1-5) keyed by agent and channel. An item
    /// whose source is disabled or gone isn't here and sorts to the bottom.
    private var sourcePriority: [String: Int] {
        var map: [String: Int] = [:]
        for ch in channels where ch.isEnabled != false {
            guard let channelId = ch.channelId, !channelId.isEmpty else { continue }
            map[ch.agentId + ":" + channelId] = ch.priority ?? 3
        }
        return map
    }

    private var filteredItems: [FeedItem] {
        var result = baseFilteredItems
        if let platformFilter {
            result = result.filter { $0.sourcePlatform == platformFilter }
        }
        switch sortMode {
        case .recent:
            break
        case .views:
            result = result.sorted { ($0.analysis?.viewsAtAnalysis ?? 0) > ($1.analysis?.viewsAtAnalysis ?? 0) }
        case .priority:
            // Priority 5 sources on top, 1 at the bottom; newest first within each.
            let priorities = sourcePriority
            func prio(_ item: FeedItem) -> Int {
                guard let agentId = item.agentId, let channelId = item.channelId else { return 0 }
                return priorities[agentId + ":" + channelId] ?? 0
            }
            result = result.sorted { a, b in
                let pa = prio(a)
                let pb = prio(b)
                if pa != pb { return pa > pb }
                return (a.publishedAt ?? "") > (b.publishedAt ?? "")
            }
        }
        return result
    }

    /// Items per platform under the current filters (a platform at 0 has no chip).
    private var platformCounts: [SourcePlatform: Int] {
        var counts: [SourcePlatform: Int] = [:]
        for item in baseFilteredItems { counts[item.sourcePlatform, default: 0] += 1 }
        return counts
    }

    /// Platforms with at least one item under the current filters. The chips only show when there is more than one.
    private var presentPlatforms: [SourcePlatform] {
        let counts = platformCounts
        return SourcePlatform.allCases.filter { (counts[$0] ?? 0) > 0 }
    }

    /// Channels for the selected agent (deduped by channel_id), limited to the
    /// selected platform chip so the dropdown only lists channels under that chip.
    private var agentChannels: [Channel] {
        guard let agentFilter else { return [] }
        var seen = Set<String>()
        return channels.filter { $0.agentId == agentFilter }
            .filter { platformFilter == nil || $0.sourcePlatform == platformFilter }
            .filter { channel in
            guard let cid = channel.channelId else { return false }
            return seen.insert(cid).inserted
        }
    }

    /// Posts for one channel under the current search, agent and status filters.
    private func channelItemCount(_ channelId: String) -> Int {
        statusSearchItems.filter { $0.channelId == channelId }.count
    }

    /// Badge on the Channel filter: how many channels are listed when it's on
    /// All Channels, or the selected channel's post count.
    private var channelTriggerBadge: String {
        guard let channelFilter else { return "\(agentChannels.count)" }
        return "\(channelItemCount(channelFilter))"
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                if !selectedIds.isEmpty { bulkBar }
                searchBar
                if presentPlatforms.count > 1 { platformChips }
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
        // A chip whose platform doesn't include the selected channel: back to
        // All Channels, since that channel is no longer in the dropdown.
        // The selected platform ran out of items, so its chip is gone: back to All.
        .onChange(of: presentPlatforms) { _, platforms in
            if let platformFilter, !platforms.contains(platformFilter) {
                self.platformFilter = nil
            }
        }
        .onChange(of: platformFilter) { _, _ in
            if let channelFilter, !agentChannels.contains(where: { $0.channelId == channelFilter }) {
                self.channelFilter = nil
            }
        }
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
        .onChange(of: router.postRequest == nil) { wasClosed, isClosed in
            if !wasClosed && isClosed {
                Task { await load() }
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
                Text("\(filteredItems.count) \(presentPlatforms.count > 1 ? "items" : "videos")")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    /// All / YouTube / X / Reddit, same chips as the web and Expo feeds.
    private var platformChips: some View {
        let counts = platformCounts
        let total = counts.values.reduce(0, +)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                platformChip(platform: nil, label: "All · \(total)")
                ForEach(SourcePlatform.allCases.filter { (counts[$0] ?? 0) > 0 }, id: \.self) { platform in
                    platformChip(platform: platform, label: "\(platform.label) · \(counts[platform] ?? 0)")
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 10)
    }

    private func platformChip(platform: SourcePlatform?, label: String) -> some View {
        let active = platformFilter == platform
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            platformFilter = platform
        } label: {
            HStack(spacing: 6) {
                if let platform { PlatformBadge(platform: platform) }
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(active ? .white : Theme.textSecondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(active ? Theme.accent : Theme.card)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(active ? Theme.accent : Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
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
                    badge: channelTriggerBadge
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
                    // How many channels are listed below (each row shows its post count)
                    PickerRow(label: "All Channels", isActive: channelFilter == nil, badge: "\(agentChannels.count)") {
                        channelFilter = nil
                        activeFilterModal = nil
                    }
                    ForEach(agentChannels) { channel in
                        PickerRow(
                            label: channel.displayName,
                            isActive: channelFilter == channel.channelId,
                            badge: "\(channelItemCount(channel.channelId ?? ""))"
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
            var fetched = try await service.fetchFeedItems()
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
                    if item.isPost { postPreview } else { thumbnail }
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

    /// Posts show their picture like the web card: the stored thumbnail, the
    /// post's own photos or video posters, the quoted post's / article's image,
    /// or a video's first frame. Only posts with nothing to show get their text.
    private var postPreview: some View {
        let text: String = {
            if item.sourcePlatform == .reddit,
               let summary = item.analysis?.shortSummary, !summary.isEmpty { return summary }
            if let body = item.body, !body.isEmpty { return body }
            return item.title ?? ""
        }()
        return Color(Theme.input)
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                PostCardVisual(
                    candidates: postThumbnailCandidates,
                    frameVideoURL: postFrameVideoURL,
                    isVideo: postIsVideo,
                    text: text
                )
                .allowsHitTesting(false)
            }
            .overlay(alignment: .topLeading) {
                PlatformBadge(platform: item.sourcePlatform, size: 24)
                    .padding(10)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) {
                // Carousel: the card shows the first photo/video; the count says how many are inside.
                let count = item.carouselMedia.count
                if count > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "square.on.square")
                            .font(.system(size: 11, weight: .semibold))
                        Text("\(count)")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.6))
                    .clipShape(Capsule())
                    .padding(10)
                    .allowsHitTesting(false)
                    .accessibilityLabel("Carousel: \(count) photos and videos")
                }
            }
            .clipped()
    }

    /// Pictures a post card can show, in order (forced to https): the stored
    /// thumbnail, the post's own photos and video posters, then a quoted post's
    /// or article's image. Instagram's go through our media-proxy, which anyone
    /// can load, the same URLs the web card uses.
    private var postThumbnailCandidates: [URL] {
        var raws: [String?] = [item.thumbnailUrl]
        raws += (item.media ?? []).filter { !$0.isEmbed }.map { $0.url }
        raws.append(item.quoteEmbed?.image)
        var urls: [URL] = []
        for case var raw? in raws where raw.hasPrefix("http") {
            if raw.hasPrefix("http://") { raw = "https://" + raw.dropFirst("http://".count) }
            if let url = URL(string: raw), !urls.contains(url) { urls.append(url) }
        }
        return urls
    }

    /// MP4 of the post's video (or the quoted post's), for a first-frame
    /// preview when there is no picture (LinkedIn often sends no poster).
    private var postFrameVideoURL: URL? {
        let own = (item.media ?? []).filter { !$0.isEmbed }.compactMap { $0.videoUrl }
        let raw = own.first(where: { $0.hasPrefix("http") }) ?? item.quoteEmbed?.videoUrl
        guard let raw, raw.hasPrefix("http") else { return nil }
        return URL(string: raw)
    }

    /// The card's first photo/video is a video: show a play button on it.
    private var postIsVideo: Bool {
        if let first = item.carouselMedia.first {
            return first.type == "video" || first.type == "animated_gif" || first.playableURL != nil
        }
        return item.quoteEmbed?.playableURL != nil
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
                    if item.isPost {
                        PlatformBadge(platform: item.sourcePlatform, size: 24)
                    } else {
                        ZStack {
                            Circle().fill(Theme.input).frame(width: 24, height: 24)
                            Circle().stroke(Theme.border, lineWidth: 0.5).frame(width: 24, height: 24)
                            Text(String((item.channelName ?? "?").prefix(1)).uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    Text("\(item.channelName ?? "Unknown channel") · \(Format.timeAgo(item.publishedAt))")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(item.isPost ? item.sourcePlatform.label : Format.duration(item.displayDurationSeconds))
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
                if item.sourcePlatform == .x {
                    statChip(icon: "bubble.left", value: item.metrics?.replies ?? 0)
                    statChip(icon: "arrow.2.squarepath", value: item.metrics?.reposts ?? 0)
                    statChip(icon: "hand.thumbsup", value: item.metrics?.likes ?? 0)
                } else if item.sourcePlatform == .reddit {
                    statChip(icon: "arrow.up", value: item.metrics?.score ?? 0)
                    statChip(icon: "bubble.left", value: item.metrics?.comments ?? 0)
                } else if item.sourcePlatform == .instagram || item.sourcePlatform == .tiktok || item.sourcePlatform == .facebook {
                    statChip(icon: "heart", value: item.metrics?.likes ?? 0)
                    statChip(icon: "bubble.right", value: item.metrics?.comments ?? 0)
                    if let plays = item.metrics?.plays, plays > 0 {
                        statChip(icon: "play", value: plays)
                    }
                } else if item.sourcePlatform == .appleMusic || item.sourcePlatform == .applePodcasts {
                    appleChip(item)
                } else if item.sourcePlatform == .github {
                    statChip(icon: "star", value: item.metrics?.stars ?? 0)
                    statChip(icon: "arrow.triangle.branch", value: item.metrics?.forks ?? 0)
                } else if item.sourcePlatform == .linkedin {
                    statChip(icon: "hand.thumbsup", value: item.metrics?.likes ?? 0)
                    statChip(icon: "text.bubble", value: item.metrics?.comments ?? 0)
                    statChip(icon: "arrow.2.squarepath", value: item.metrics?.reposts ?? 0)
                } else {
                    statChip(icon: "eye", value: item.displayViews)
                    statChip(icon: "hand.thumbsup", value: item.displayLikes)
                    statChip(icon: "bubble.left", value: item.displayComments)
                }
                Spacer()
            }
            .padding(.top, 10)
        }
        .padding(12)
    }

    /// Apple Music: "New single" / "Latest album"; Apple Podcasts: the episode length.
    @ViewBuilder
    private func appleChip(_ item: FeedItem) -> some View {
        let media = item.media?.first { $0.type == "album" || $0.type == "audio" }
        HStack(spacing: 4) {
            if item.sourcePlatform == .applePodcasts {
                Image(systemName: "headphones")
                    .font(.system(size: 11))
                if let seconds = media?.duration, seconds > 0 {
                    Text(seconds >= 3600
                         ? "\(seconds / 3600) h \((seconds % 3600) / 60) min"
                         : "\(max(1, seconds / 60)) min")
                        .font(.system(size: 12))
                } else {
                    Text("Episode").font(.system(size: 12))
                }
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 11))
                Text(media?.label ?? "New release")
                    .font(.system(size: 12))
            }
        }
        .foregroundStyle(Theme.textMuted)
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

    /// First frame of a video with no poster (LinkedIn often sends none).
    func videoFrame(_ url: URL) async -> UIImage? {
        if let image = cached(url) { return image }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 960, height: 960)
        guard let frame = try? await generator.image(at: CMTime(seconds: 0.1, preferredTimescale: 600)) else { return nil }
        let image = UIImage(cgImage: frame.image)
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

/// A post card's picture: the first of the candidates that loads, else a
/// video's first frame. The post's text shows only when the source has
/// nothing to show or nothing loads.
private struct PostCardVisual: View {
    let candidates: [URL]
    let frameVideoURL: URL?
    let isVideo: Bool
    let text: String
    @State private var image: UIImage?
    @State private var failed = false

    init(candidates: [URL], frameVideoURL: URL?, isVideo: Bool, text: String) {
        self.candidates = candidates
        self.frameVideoURL = frameVideoURL
        self.isVideo = isVideo
        self.text = text
        let cached = candidates.lazy.compactMap { ThumbnailCache.shared.cached($0) }.first
            ?? frameVideoURL.flatMap { ThumbnailCache.shared.cached($0) }
        _image = State(initialValue: cached)
    }

    private var hasNothingToShow: Bool { candidates.isEmpty && frameVideoURL == nil }

    var body: some View {
        ZStack {
            if let image {
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(.rect(cornerRadius: 8))
                .overlay {
                    if isVideo {
                        Image(systemName: "play.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 44)
                .padding(.bottom, 10)
                .transition(.opacity)
            } else if failed || hasNothingToShow {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textPrimary)
                    .lineSpacing(3)
                    .lineLimit(6)
                    .padding(.horizontal, 14)
                    .padding(.top, 30)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .task(id: candidates) { await load() }
    }

    private func load() async {
        if image != nil { return }
        failed = false
        if !candidates.isEmpty {
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
        if let frameVideoURL, !Task.isCancelled,
           let frame = await ThumbnailCache.shared.videoFrame(frameVideoURL) {
            withAnimation(.easeIn(duration: 0.15)) { image = frame }
            return
        }
        if !Task.isCancelled { failed = true }
    }
}
