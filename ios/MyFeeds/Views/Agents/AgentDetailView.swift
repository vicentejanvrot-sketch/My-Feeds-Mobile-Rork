import SwiftUI

struct AgentDetailView: View {
    let agentId: String

    @Environment(RunningOverlayStore.self) private var overlay
    @Environment(ToastCenter.self) private var toasts
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var agent: Agent?
    @State private var channels: [Channel] = []
    @State private var recipients: [AgentRecipient] = []
    @State private var runs: [Run] = []
    @State private var runItemCounts: [String: [ItemStatus: Int]] = [:]
    @State private var isLoading = true
    @State private var isOffline = false

    @State private var channelStatusFilter: ItemStatus?
    @State private var filterAll = true
    @State private var showFilterModal = false
    @State private var priorityModalChannel: Channel?
    @State private var showAddRecipient = false
    @State private var showAddChannel = false
    @State private var newRecipientEmail = ""
    @State private var newChannelUrl = ""
    @State private var newChannelPriority = 3
    @State private var newSourcePlatform: SourcePlatform = .youtube
    /// Set when a pasted link picked the platform for the user.
    @State private var autoPlatform: SourcePlatform?
    /// Set when Instagram says the account is private (or can't be loaded), so
    /// the sheet can offer to add it as a private account.
    @State private var privateOffer: String?
    @State private var isSubmittingModal = false
    @State private var recipientToRemove: AgentRecipient?
    @State private var channelToRemove: Channel?
    @State private var runToCancel: Run?
    @State private var showDeleteAgent = false
    @State private var isDeletingAgent = false

    /// The agent's own colour: its place in the alphabetical agent list, same as
    /// the dashboard and agents list.
    @State private var accentIndex = 0
    private var accent: Color { Theme.agentAccent(accentIndex) }

    private var filteredChannels: [Channel] {
        guard !filterAll, let filter = channelStatusFilter else { return channels }
        return channels.filter { ($0.userStatus ?? .notWatched) == filter }
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if isOffline { offlineBanner }
                    if isLoading {
                        ProgressView()
                            .controlSize(.large)
                            .tint(Theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 80)
                    } else if let agent {
                        headerCard(agent)
                        scheduleCard(agent)
                        filtersCard(agent)
                        recipientsSection
                        channelsSection
                        runHistorySection
                    } else {
                        Text("Collection not found")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 80)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .scrollDisabled(overlay.isVisible)

            modalOverlays
        }
        .background(Theme.background)
        .navigationTitle(agent?.name ?? "Collection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .refreshable { await load() }
        .task { await load() }
        .onChange(of: overlay.runCompletionCounter) {
            Task { await load() }
        }
        .alert("Remove Recipient", isPresented: Binding(
            get: { recipientToRemove != nil },
            set: { if !$0 { recipientToRemove = nil } }
        )) {
            Button("Cancel", role: .cancel) { recipientToRemove = nil }
            Button("Remove", role: .destructive) {
                if let recipient = recipientToRemove { removeRecipient(recipient) }
            }
        } message: {
            Text("Remove \(recipientToRemove?.email ?? "")?")
        }
        .alert("Remove Channel", isPresented: Binding(
            get: { channelToRemove != nil },
            set: { if !$0 { channelToRemove = nil } }
        )) {
            Button("Cancel", role: .cancel) { channelToRemove = nil }
            Button("Remove", role: .destructive) {
                if let channel = channelToRemove { removeChannel(channel) }
            }
        } message: {
            Text("Remove \"\(channelToRemove?.displayName ?? "")\" from this collection?")
        }
        .alert("Cancel Run", isPresented: Binding(
            get: { runToCancel != nil },
            set: { if !$0 { runToCancel = nil } }
        )) {
            Button("Keep Running", role: .cancel) { runToCancel = nil }
            Button("Cancel Run", role: .destructive) {
                if let run = runToCancel { cancelRun(run) }
            }
        } message: {
            Text("Stop this run in progress?")
        }
        .alert("Delete \(agent?.name ?? "collection")?", isPresented: $showDeleteAgent) {
            Button("Cancel", role: .cancel) {}
            Button("Delete collection", role: .destructive) { deleteThisAgent() }
        } message: {
            Text("This deletes the collection, its \(channels.count) \(channels.count == 1 ? "source" : "sources"), its email recipients, its run history and every video and post it found, including ones you saved. It can't be undone. Your accounts on YouTube, X and the other platforms aren't touched.")
        }
    }

    /// The database deletes the agent's sources, recipients, runs and found
    /// items along with it.
    private func deleteThisAgent() {
        guard let agent, !isDeletingAgent else { return }
        isDeletingAgent = true
        Task {
            do {
                try await SupabaseService.shared.deleteAgent(id: agent.id)
                toasts.show("Collection deleted")
                dismiss()
            } catch {
                toasts.show(error.localizedDescription, type: .error)
            }
            isDeletingAgent = false
        }
    }

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 13))
            Text("Offline — couldn't load latest collection data.")
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Button {
                Task { await load() }
            } label: {
                Text("Retry")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(hsl: 38, 92, 50, alpha: 0.16))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(hsl: 38, 92, 50, alpha: 0.3)).frame(height: 0.5)
        }
        .padding(.bottom, 10)
    }

    // MARK: - Header card

    private func headerCard(_ agent: Agent) -> some View {
        HStack(spacing: 0) {
            Rectangle().fill(accent).frame(width: 4)
            VStack(alignment: .leading, spacing: 0) {
                Text(agent.name)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                if let description = agent.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                        .lineSpacing(4)
                        .padding(.top, 6)
                }
                HStack(spacing: 10) {
                    Button {
                        Task { await overlay.run(agent: agent) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                            Text("Run Now")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.accentGradient)
                        .clipShape(.rect(cornerRadius: 10))
                    }
                    .disabled(overlay.pendingId != nil)

                    // This collection's posts in the Feeds tab, already filtered to it.
                    Button {
                        // Opened from the Feeds tab: go back to it instead of
                        // leaving this screen on top of the feed.
                        if router.selectedTab == .feed { dismiss() }
                        router.openFeed(agentId: agent.id, status: nil)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "dot.radiowaves.up.forward")
                                .font(.system(size: 14))
                            Text("Feed")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Theme.border, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View this collection's feed")

                    NavigationLink(value: AppRoute.agentForm(agent.id)) {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                                .font(.system(size: 14))
                            Text("Edit")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Theme.border, lineWidth: 1.5)
                        )
                    }

                    Button {
                        showDeleteAgent = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.destructive)
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Theme.destructive, lineWidth: 1.5)
                            )
                    }
                    .disabled(isDeletingAgent)
                    .accessibilityLabel("Delete collection")
                }
                .padding(.top, 18)
            }
            .padding(16)
        }
        .cardStyle(radius: 12)
        .padding(.bottom, 10)
    }

    // MARK: - Info cards

    private func scheduleCard(_ agent: Agent) -> some View {
        let title: String = {
            if let time = agent.runTimeLocal, !time.isEmpty {
                return "\(time) (\(agent.timezone ?? "UTC"))"
            }
            return "No schedule set"
        }()
        let subtitle: String? = {
            let frequency = agent.scheduleFrequency ?? "Manual"
            if let lookback = agent.lookbackHours {
                return "\(frequency) • \(lookback)h lookback"
            }
            return frequency
        }()
        return infoCard(icon: "clock", title: title, subtitle: subtitle) { EmptyView() }
    }

    private func filtersCard(_ agent: Agent) -> some View {
        infoCard(icon: "star", title: "Filters", subtitle: nil) {
            VStack(alignment: .leading, spacing: 6) {
                booleanRow(label: "Shorts", isOn: agent.includeShorts == true)
                booleanRow(label: "Live/Upcoming", isOn: agent.includeLive == true)
            }
            .padding(.top, 6)
        }
    }

    private func infoCard<Extra: View>(
        icon: String,
        title: String,
        subtitle: String?,
        @ViewBuilder extra: () -> Extra
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.input)
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                extra()
            }
            Spacer()
        }
        .padding(14)
        .cardStyle(radius: 10)
        .padding(.bottom, 10)
    }

    private func booleanRow(label: String, isOn: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isOn ? "checkmark" : "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isOn ? Theme.success : Theme.textMuted)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isOn ? Theme.textPrimary : Theme.textMuted)
        }
    }

    // MARK: - Recipients

    @ViewBuilder
    private var recipientsSection: some View {
        if !recipients.isEmpty {
            SectionHeader(title: "Recipients (\(recipients.count))", actionLabel: "+ Add") {
                newRecipientEmail = ""
                showAddRecipient = true
            }
            FlowLayoutWrap(spacing: 8) {
                ForEach(recipients) { recipient in
                    HStack(spacing: 6) {
                        Image(systemName: "envelope")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textSecondary)
                        Text(recipient.email)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                            .frame(maxWidth: 180, alignment: .leading)
                            .fixedSize(horizontal: true, vertical: false)
                        Button {
                            recipientToRemove = recipient
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.textMuted)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.card)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Theme.border, lineWidth: 0.5))
                }
            }
        }
    }

    // MARK: - Channels

    private var channelsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("SOURCES (\(channels.count))")
                    .font(.system(size: 13, weight: .bold))
                    .kerning(0.6)
                    .foregroundStyle(Theme.textSecondary)
                if !filterAll {
                    Text("\(filteredChannels.count) of \(channels.count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Theme.accent.opacity(0.1))
                        .clipShape(Capsule())
                }
                Spacer()
                Button {
                    newChannelUrl = ""
                    newChannelPriority = 3
                    newSourcePlatform = .youtube
                    autoPlatform = nil
                    privateOffer = nil
                    showAddChannel = true
                } label: {
                    Text("+ Add Source")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.top, 26)
            .padding(.bottom, 12)

            // Filter row
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                Text("Filter by status:")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Button {
                    showFilterModal = true
                } label: {
                    HStack {
                        Text(filterAll ? "All Channels" : (channelStatusFilter?.label ?? "All Channels"))
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Theme.input)
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.border, lineWidth: 0.5)
                    )
                }
            }
            .padding(.bottom, 12)

            if filteredChannels.isEmpty {
                Text(filterAll ? "No channels added yet." : "No channels match this filter.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .cardStyle(radius: 12)
            } else {
                ForEach(filteredChannels) { channel in
                    channelCard(channel)
                }
            }
        }
    }

    private func channelCard(_ channel: Channel) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Color(Theme.input)
                .frame(width: 72, height: 72)
                .overlay {
                    if let thumbnail = channel.channelThumbnail, let url = URL(string: thumbnail) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Image(systemName: "photo")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Theme.textMuted)
                            }
                        }
                        .allowsHitTesting(false)
                    } else if channel.sourcePlatform != .youtube {
                        PlatformBadge(platform: channel.sourcePlatform, size: 32)
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.textMuted)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    // X accounts and subreddits with a picture still show where they come from.
                    if channel.sourcePlatform != .youtube, channel.channelThumbnail != nil {
                        PlatformBadge(platform: channel.sourcePlatform, size: 18)
                            .padding(4)
                    }
                }
                .clipped()

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Button {
                        if let urlString = channel.channelUrl, let url = URL(string: urlString) {
                            openURL(url)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(channel.displayName)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            if channel.channelUrl != nil {
                                Image(systemName: "link")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            if channel.isPrivateAccount {
                                HStack(spacing: 3) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 8))
                                    Text("Private")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundStyle(Theme.textMuted)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                                .padding(.leading, 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button {
                        channelToRemove = channel
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.destructive)
                    }
                }

                if channel.channelName != nil, let urlString = channel.channelUrl {
                    Text(urlString)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.accent)
                        .lineLimit(1)
                        .padding(.top, 2)
                }

                HStack {
                    Button {
                        priorityModalChannel = channel
                    } label: {
                        HStack(spacing: 4) {
                            Text("\(channel.priority ?? 3)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.warning)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(Theme.textMuted)
                        }
                        .frame(width: 80, height: 28)
                        .background(Theme.card)
                        .clipShape(.rect(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Theme.border, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    HStack(spacing: 6) {
                        Toggle("", isOn: Binding(
                            get: { channel.isEnabled ?? true },
                            set: { toggleChannel(channel, isEnabled: $0) }
                        ))
                        .labelsHidden()
                        .tint(Theme.accent)
                        .scaleEffect(0.8)
                        Text((channel.isEnabled ?? true) ? "On" : "Off")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.top, 10)

                Text(channel.isPrivateAccount
                     ? "Not scanned (private)"
                     : channel.lastScannedAt != nil
                     ? "Scanned \(Format.timeAgo(channel.lastScannedAt))"
                     : "Never scanned")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.top, 8)
            }
            .padding(12)
        }
        .cardStyle(radius: 12)
        .padding(.bottom, 10)
    }

    // MARK: - Run history

    private var runHistorySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Run History (\(runs.count))")

            if runs.isEmpty {
                Text("No runs yet. Tap \"Run Now\" to start one.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .cardStyle(radius: 12)
            } else {
                ForEach(runs) { run in
                    runCard(run)
                }
            }
        }
    }

    private func runCard(_ run: Run) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                StatusPill(status: run.runStatus)
                Spacer()
                Text(Format.timeAgo(run.startedAt))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
            }

            Text("\(Format.runTimestamp(run.startedAt)) · \(Format.runDuration(started: run.startedAt, finished: run.finishedAt))")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
                .padding(.top, 6)

            if let statusCounts = runItemCounts[run.id], !statusCounts.isEmpty {
                let total = statusCounts.values.reduce(0, +)
                VStack(spacing: 6) {
                    ForEach([ItemStatus.watched, .notWatched, .liked, .watchLater], id: \.self) { status in
                        if let count = statusCounts[status], count > 0 {
                            HStack(spacing: 8) {
                                HStack(spacing: 6) {
                                    Circle().fill(status.color).frame(width: 6, height: 6)
                                    Text(shortStatusLabel(status))
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .frame(width: 90, alignment: .leading)
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Theme.input)
                                        Capsule().fill(status.color)
                                            .frame(width: geo.size.width * CGFloat(count) / CGFloat(max(total, 1)))
                                    }
                                }
                                .frame(height: 5)
                                Text("\(count)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Theme.textPrimary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .padding(.top, 12)
            }

            HStack(spacing: 0) {
                runStat(value: run.videosFoundCount ?? 0, label: "Found")
                runStat(value: run.videosNewCount ?? 0, label: "New")
                runStat(value: run.videosEnrichedCount ?? 0, label: "Enriched")
                VStack(spacing: 2) {
                    Text("\(run.channelsScanned ?? 0)/\(run.channelsTotal ?? 0)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                    Text("Channels")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 12)

            if let summary = run.errorSummary, !summary.isEmpty, run.runStatus != .success, run.runStatus != .running {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: run.runStatus == .cancelled ? "nosign" : "exclamationmark.triangle")
                        .font(.system(size: 12))
                    Text(summary)
                        .font(.system(size: 12))
                        .lineLimit(3)
                }
                .foregroundStyle(run.runStatus == .failed ? Theme.destructive : (run.runStatus == .partial ? Theme.warning : Theme.textMuted))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(run.runStatus == .failed
                            ? Theme.destructiveBg
                            : (run.runStatus == .partial
                               ? Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255).opacity(0.12)
                               : Color(red: 96 / 255, green: 105 / 255, blue: 119 / 255).opacity(0.15)))
                .clipShape(.rect(cornerRadius: 8))
                .padding(.top, 12)
            }

            if run.runStatus == .running {
                Button {
                    runToCancel = run
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Cancel Run")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Theme.destructive)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.destructive, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
            }
        }
        .padding(16)
        .cardStyle(radius: 12)
        .padding(.bottom, 10)
    }

    private func shortStatusLabel(_ status: ItemStatus) -> String {
        switch status {
        case .watched: return "Watched"
        case .notWatched: return "Not watched"
        case .liked: return "Liked"
        case .watchLater: return "Later"
        }
    }

    private func runStat(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Modals

    @ViewBuilder
    private var modalOverlays: some View {
        if showFilterModal {
            PickerModal(title: "Filter by status", onDismiss: { showFilterModal = false }) {
                PickerRow(label: "All Channels", isActive: filterAll) {
                    filterAll = true
                    channelStatusFilter = nil
                    showFilterModal = false
                }
                ForEach(ItemStatus.allCases, id: \.self) { status in
                    PickerRow(label: status.label, isActive: !filterAll && channelStatusFilter == status) {
                        filterAll = false
                        channelStatusFilter = status
                        showFilterModal = false
                    }
                }
            }
        }

        if let channel = priorityModalChannel {
            PickerModal(title: "Priority", onDismiss: { priorityModalChannel = nil }) {
                ForEach([5, 4, 3, 2, 1], id: \.self) { priority in
                    PickerRow(
                        label: "\(priority)",
                        isActive: (channel.priority ?? 3) == priority,
                        iconName: "star.fill",
                        iconColor: Theme.warning
                    ) {
                        priorityModalChannel = nil
                        setChannelPriority(channel, priority: priority)
                    }
                }
            }
        }

        if showAddRecipient {
            inputModal(
                title: "Add Recipient",
                placeholder: "email@example.com",
                text: $newRecipientEmail,
                confirmLabel: "Add Recipient",
                confirmDisabled: !newRecipientEmail.contains("@"),
                keyboard: .emailAddress,
                onDismiss: { showAddRecipient = false },
                onConfirm: { addRecipient() }
            )
        }

        if showAddChannel {
            addChannelModal
        }
    }

    private func inputModal(
        title: String,
        placeholder: String,
        text: Binding<String>,
        confirmLabel: String,
        confirmDisabled: Bool,
        keyboard: UIKeyboardType,
        onDismiss: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) -> some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea().onTapGesture { onDismiss() }
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                TextField(placeholder, text: text)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textPrimary)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Theme.input)
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                Button(action: onConfirm) {
                    ZStack {
                        if isSubmittingModal {
                            ProgressView().tint(.white)
                        } else {
                            Text(confirmLabel)
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Theme.accent)
                    .clipShape(.rect(cornerRadius: 10))
                    .opacity(confirmDisabled ? 0.5 : 1)
                }
                .disabled(confirmDisabled || isSubmittingModal)
            }
            .padding(20)
            .frame(maxWidth: 400)
            .background(Theme.card)
            .clipShape(.rect(cornerRadius: 16))
            .padding(.horizontal, 24)
        }
    }

    private var addChannelModal: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea().onTapGesture { showAddChannel = false }
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Add Source")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Button { showAddChannel = false } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Text("Platform")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(SourcePlatform.addable, id: \.self) { platform in
                        let active = newSourcePlatform == platform
                        Button {
                            newSourcePlatform = platform
                            autoPlatform = nil
                        } label: {
                            HStack(spacing: 6) {
                                PlatformBadge(platform: platform)
                                Text(platform.label)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(active ? .white : Theme.textSecondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(active ? Theme.accent.opacity(0.13) : Theme.input)
                            .clipShape(.rect(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(active ? Theme.accent : Theme.border, lineWidth: 1)
                            )
                            .overlay(alignment: .topTrailing) {
                                // Instagram and LinkedIn are still in beta.
                                if platform.isBeta {
                                    Text("BETA")
                                        .font(.system(size: 8, weight: .heavy))
                                        .kerning(0.4)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Theme.accent)
                                        .clipShape(Capsule())
                                        .offset(x: -4, y: -6)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(active ? .isSelected : [])
                    }
                }
                Text(newSourcePlatform == .youtube ? "Channel URL" : newSourcePlatform.sourceNoun)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                TextField(newSourcePlatform.addPlaceholder, text: $newChannelUrl)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textPrimary)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Theme.input)
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .onChange(of: newChannelUrl) { _, value in
                        privateOffer = nil
                        if let detected = SourcePlatform.detect(from: value), detected != newSourcePlatform {
                            newSourcePlatform = detected
                            autoPlatform = detected
                        } else if value.trimmingCharacters(in: .whitespaces).isEmpty {
                            autoPlatform = nil
                        }
                    }
                if autoPlatform == newSourcePlatform {
                    Text("That's a \(newSourcePlatform.label) link, so \(newSourcePlatform.label) is now selected.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.accent)
                } else {
                    Text(newSourcePlatform.addHelp)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
                }
                if let privateOffer {
                    privateOfferBox(privateOffer)
                }
                Text("Priority")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { priority in
                        Button {
                            newChannelPriority = priority
                        } label: {
                            Text("\(priority)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(newChannelPriority == priority ? .white : Theme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(newChannelPriority == priority ? Theme.accent.opacity(0.13) : Theme.input)
                                .clipShape(.rect(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(newChannelPriority == priority ? Theme.accent : Theme.border, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button {
                    addChannel()
                } label: {
                    ZStack {
                        if isSubmittingModal {
                            ProgressView().tint(.white)
                        } else {
                            Text("Add \(newSourcePlatform.sourceNoun)")
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Theme.accent)
                    .clipShape(.rect(cornerRadius: 10))
                    .opacity(newChannelUrl.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                }
                .disabled(newChannelUrl.trimmingCharacters(in: .whitespaces).isEmpty || isSubmittingModal)
            }
            .padding(20)
            .frame(maxWidth: 400)
            .background(Theme.card)
            .clipShape(.rect(cornerRadius: 16))
            .padding(.horizontal, 24)
        }
    }

    /// "Add as private account", shown when Instagram says the account is private.
    private func privateOfferBox(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.top, 2)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("A private account shows up on People with a button to open it in Instagram. Its posts won't appear in your feed.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                addChannel(asPrivate: true)
            } label: {
                HStack(spacing: 6) {
                    if isSubmittingModal {
                        ProgressView().tint(Theme.textPrimary)
                    } else {
                        Image(systemName: "lock.fill").font(.system(size: 12))
                        Text("Add as private account").font(.system(size: 13, weight: .semibold))
                    }
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(isSubmittingModal)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.input)
        .clipShape(.rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Data & mutations

    private func load() async {
        let service = SupabaseService.shared
        do {
            async let agentTask = service.fetchAgent(id: agentId)
            async let channelsTask = service.fetchChannels(agentId: agentId)
            async let recipientsTask = service.fetchRecipients(agentId: agentId)
            async let runsTask = service.fetchAgentRuns(agentId: agentId, limit: 30)
            let (loadedAgent, loadedChannels, loadedRecipients, loadedRuns) =
                try await (agentTask, channelsTask, recipientsTask, runsTask)
            agent = loadedAgent
            channels = loadedChannels
            recipients = loadedRecipients
            runs = loadedRuns
            isLoading = false
            isOffline = false

            if let allAgents = try? await service.fetchAgents() {
                let sorted = allAgents.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                accentIndex = sorted.firstIndex { $0.id == agentId } ?? 0
            }

            let statuses = try await service.fetchRunItemStatuses(runIds: loadedRuns.map(\.id))
            var grouped: [String: [ItemStatus: Int]] = [:]
            for row in statuses {
                guard let runId = row.runId else { continue }
                let status = row.userStatus ?? .notWatched
                grouped[runId, default: [:]][status, default: 0] += 1
            }
            runItemCounts = grouped
        } catch {
            // A cancelled load (leaving the screen) isn't being offline.
            if !error.isCancellation { isOffline = true }
            isLoading = false
        }
    }

    private func toggleChannel(_ channel: Channel, isEnabled: Bool) {
        if let index = channels.firstIndex(where: { $0.id == channel.id }) {
            channels[index].isEnabled = isEnabled
        }
        Task {
            do {
                try await SupabaseService.shared.toggleChannel(id: channel.id, isEnabled: isEnabled)
            } catch {
                toasts.show("Couldn't update channel", type: .error)
                await load()
            }
        }
    }

    private func setChannelPriority(_ channel: Channel, priority: Int) {
        if let index = channels.firstIndex(where: { $0.id == channel.id }) {
            channels[index].priority = priority
        }
        Task {
            do {
                try await SupabaseService.shared.updateChannelPriority(id: channel.id, priority: priority)
                await load()
            } catch {
                toasts.show("Couldn't update priority", type: .error)
                await load()
            }
        }
    }

    private func removeChannel(_ channel: Channel) {
        Task {
            do {
                try await SupabaseService.shared.deleteChannel(id: channel.id)
                toasts.show("Channel removed")
                await load()
            } catch {
                toasts.show("Couldn't remove channel", type: .error)
            }
            channelToRemove = nil
        }
    }

    private func addChannel(asPrivate: Bool = false) {
        let url = newChannelUrl.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }
        privateOffer = nil
        // The link says one platform but another is selected (picked after pasting).
        if let detected = SourcePlatform.detect(from: url), detected != newSourcePlatform {
            toasts.show("That's a \(detected.label) link. Select \(detected.label) or paste a \(newSourcePlatform.label) link.", type: .error)
            return
        }
        isSubmittingModal = true
        Task {
            do {
                if newSourcePlatform == .youtube {
                    try await SupabaseService.shared.addChannel(agentId: agentId, url: url, priority: newChannelPriority)
                    toasts.show("Channel added")
                } else {
                    // X accounts and subreddits are checked and named by the add-source function.
                    let channel = try await SupabaseService.shared.addSource(
                        agentId: agentId,
                        platform: newSourcePlatform,
                        value: url,
                        priority: newChannelPriority,
                        privateAccount: asPrivate
                    )
                    toasts.show(channel.isPrivateAccount
                        ? "Added \(channel.displayName) as a private account"
                        : "Added \(channel.displayName)")
                }
                showAddChannel = false
                await load()
            } catch let error as SourceError where !asPrivate && error.canAddAsPrivate {
                privateOffer = error.message
            } catch {
                let fallback = "Couldn't add \(newSourcePlatform.sourceNoun.lowercased())"
                toasts.show((error as? SourceError)?.message ?? fallback, type: .error)
            }
            isSubmittingModal = false
        }
    }

    private func addRecipient() {
        let email = newRecipientEmail.trimmingCharacters(in: .whitespaces)
        guard email.contains("@") else { return }
        isSubmittingModal = true
        Task {
            do {
                try await SupabaseService.shared.addRecipient(agentId: agentId, email: email)
                toasts.show("Recipient added")
                showAddRecipient = false
                await load()
            } catch {
                toasts.show("Couldn't add recipient", type: .error)
            }
            isSubmittingModal = false
        }
    }

    private func removeRecipient(_ recipient: AgentRecipient) {
        Task {
            do {
                try await SupabaseService.shared.deleteRecipient(id: recipient.id)
                toasts.show("Recipient removed")
                await load()
            } catch {
                toasts.show("Couldn't remove recipient", type: .error)
            }
            recipientToRemove = nil
        }
    }

    private func cancelRun(_ run: Run) {
        Task {
            do {
                try await SupabaseService.shared.cancelRun(runId: run.id)
                toasts.show("Run cancelled", type: .info)
                await load()
            } catch {
                toasts.show("Failed to cancel run", type: .error)
            }
            runToCancel = nil
        }
    }
}

/// Simple wrapping flow layout for chips.
struct FlowLayoutWrap: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
