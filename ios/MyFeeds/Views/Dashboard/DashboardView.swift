import SwiftUI

struct DashboardView: View {
    @Environment(AppRouter.self) private var router
    @Environment(RunningOverlayStore.self) private var overlay
    @Environment(ToastCenter.self) private var toasts

    @State private var agents: [Agent] = []
    @State private var runs: [Run] = []
    @State private var channels: [Channel] = []
    @State private var counts: [String: AgentItemCounts] = [:]
    @State private var isLoading = true
    @State private var isOffline = false
    @State private var agentToDelete: Agent?
    // Onboarding wizard: opens by itself once per launch until the user ticks
    // "Don't show this again"; the ? button next to the title opens it any time.
    @State private var wizardOpen = false
    @State private var wizardKey = 0
    // The Feeds and My Collections sections open and close. They start closed,
    // and how the user left them is kept on the phone, so the dashboard looks
    // the same when they come back from a feed. Same on the web app and Android.
    @AppStorage("dashboard.feedsOpen") private var feedsOpen = false
    @AppStorage("dashboard.collectionsOpen") private var collectionsOpen = false

    private var sortedAgents: [Agent] {
        agents.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var successRate: Int {
        guard !runs.isEmpty else { return 0 }
        let successCount = runs.filter { $0.runStatus == .success }.count
        return Int((Double(successCount) / Double(runs.count) * 100).rounded())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .tint(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else {
                    if isOffline { offlineBanner }
                    statGrid
                    followingCard

                    CollapsibleSectionHeader(
                        title: "Feeds",
                        count: sortedAgents.count,
                        isOpen: $feedsOpen,
                        actionLabel: agents.isEmpty ? nil : "View All"
                    ) {
                        router.openFeed(agentId: nil, status: nil)
                    }
                    if !feedsOpen {
                        EmptyView()
                    } else if sortedAgents.isEmpty {
                        emptyCard(text: "No collections yet. Create one to get started.")
                    } else {
                        ForEach(Array(sortedAgents.enumerated()), id: \.element.id) { index, agent in
                            FeedCardView(
                                agent: agent,
                                accent: Theme.agentAccent(index),
                                counts: counts[agent.id] ?? AgentItemCounts()
                            ) {
                                let c = counts[agent.id] ?? AgentItemCounts()
                                let status: ItemStatus
                                if c.unwatched > 0 { status = .notWatched }
                                else if c.watchLater > 0 { status = .watchLater }
                                else if c.watched > 0 { status = .watched }
                                else { status = .notWatched }
                                router.openFeed(agentId: agent.id, status: status)
                            }
                        }
                    }

                    WatchTimeStatsSection()

                    CollapsibleSectionHeader(
                        title: "My Collections",
                        count: sortedAgents.count,
                        isOpen: $collectionsOpen
                    )
                    if !collectionsOpen {
                        EmptyView()
                    } else if sortedAgents.isEmpty {
                        emptyCard(text: "No collections yet. Create one to get started.")
                    } else {
                        ForEach(Array(sortedAgents.enumerated()), id: \.element.id) { index, agent in
                            DashboardAgentCard(
                                agent: agent,
                                accent: Theme.agentAccent(index),
                                channelCount: channels.filter { $0.agentId == agent.id }.count,
                                lastSuccessRun: runs.first { $0.agentId == agent.id && $0.runStatus == .success },
                                isPending: overlay.pendingId == agent.id,
                                anyPending: overlay.pendingId != nil,
                                onRun: { Task { await overlay.run(agent: agent) } },
                                onDelete: { agentToDelete = agent }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 70)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await load() }
        .task { await load() }
        .task {
            if await OnboardingPrefs.shouldAutoOpen() { openWizard() }
        }
        .fullScreenCover(isPresented: $wizardOpen) {
            OnboardingWizardView(
                hidden: OnboardingPrefs.isHidden,
                onHiddenChange: { hidden in saveOnboardingHidden(hidden) },
                onClose: { result in handleWizardClose(result) }
            )
            .id(wizardKey)
        }
        .onChange(of: overlay.runCompletionCounter) {
            Task { await load() }
        }
        .alert("Delete Collection", isPresented: Binding(
            get: { agentToDelete != nil },
            set: { if !$0 { agentToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { agentToDelete = nil }
            Button("Delete", role: .destructive) {
                if let agent = agentToDelete { deleteAgent(agent) }
            }
        } message: {
            Text("Delete \"\(agentToDelete?.name ?? "")\"? This cannot be undone.")
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("Dashboard")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 0)
                helpButton
            }

            HStack(spacing: 10) {
                NavigationLink(value: AppRoute.agentForm(nil)) {
                    Text("+ New Collection")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Theme.accent)
                        .clipShape(.rect(cornerRadius: 10))
                }

                if !agents.isEmpty {
                    Button {
                        let toRun = sortedAgents
                        Task { await overlay.runAll(agents: toRun) }
                    } label: {
                        HStack(spacing: 6) {
                            if overlay.pendingId == "all" {
                                ProgressView().tint(.white).controlSize(.small)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 14))
                                Text("Run All")
                                    .font(.system(size: 13, weight: .bold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(height: 38)
                        .frame(minWidth: 90)
                        .padding(.horizontal, 14)
                        .background(Theme.success)
                        .clipShape(.rect(cornerRadius: 10))
                    }
                    .disabled(overlay.pendingId != nil)
                }
                Spacer()
            }
        }
        .padding(.bottom, 20)
    }

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatCard(icon: "cpu", label: "Active Collections", value: "\(agents.count)")
            StatCard(icon: "video", label: "Channels Tracked", value: "\(channels.count)")
            StatCard(icon: "waveform.path.ecg", label: "Recent Runs", value: "\(runs.count)")
            StatCard(icon: "chart.line.uptrend.xyaxis", label: "Success Rate", value: "\(successRate)%")
        }
    }

    /// Opens the Following screen: everyone the user follows and where else they are.
    private var followingCard: some View {
        NavigationLink(value: AppRoute.following) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hsl: 199, 89, 55, alpha: 0.16))
                        .frame(width: 34, height: 34)
                    Image(systemName: "person.2")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(hsl: 199, 89, 55))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("People")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Everyone you follow, and where else they are")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
            }
            .padding(14)
            .background(Theme.card)
            .clipShape(.rect(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
        .accessibilityLabel("People: everyone you follow, and where else they are")
    }

    private func emptyCard(text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(20)
            .cardStyle(radius: 10)
    }

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 13))
            Text("Offline — couldn't load latest data.")
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
        .padding(.bottom, 12)
    }

    // MARK: - Wizard

    /// Light red for the ? button, so it's easy to spot without shouting.
    private static let helpRed = Color(red: 1, green: 138 / 255, blue: 138 / 255)

    /// Small ? next to the title that opens the onboarding wizard again.
    private var helpButton: some View {
        Button {
            openWizard()
        } label: {
            Image(systemName: "questionmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Self.helpRed)
                .frame(width: 30, height: 30)
                .overlay(Circle().stroke(Self.helpRed, lineWidth: 1))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, -7)
        .accessibilityLabel("How it works")
    }

    /// A new id gives the wizard fresh state each time it opens.
    private func openWizard() {
        OnboardingPrefs.markShown()
        wizardKey += 1
        wizardOpen = true
    }

    private func saveOnboardingHidden(_ hidden: Bool) {
        Task {
            if let message = await OnboardingPrefs.setHidden(hidden) {
                toasts.show("Couldn't save that setting: \(message)", type: .error)
            }
        }
    }

    /// Closed from the last screen: say it worked and start the first run if asked.
    private func handleWizardClose(_ result: OnboardingResult?) {
        wizardOpen = false
        guard let result else { return }
        toasts.show("\(result.agent.name) is set up")
        Task {
            await load()
            if result.runNow {
                await overlay.run(agent: result.agent)
            }
        }
    }

    // MARK: - Data

    private func load() async {
        let service = SupabaseService.shared
        do {
            async let agentsTask = service.fetchAgents()
            async let runsTask = service.fetchRuns(limit: 50)
            async let channelsTask = service.fetchAllChannels()
            let (loadedAgents, loadedRuns, loadedChannels) = try await (agentsTask, runsTask, channelsTask)
            agents = loadedAgents
            runs = loadedRuns
            channels = loadedChannels
            isLoading = false
            isOffline = false
            counts = (try? await service.fetchAgentItemCounts(agentIds: loadedAgents.map(\.id))) ?? [:]
        } catch {
            // A cancelled load (tab switch) isn't being offline.
            if !error.isCancellation { isOffline = true }
            isLoading = false
        }
    }

    private func deleteAgent(_ agent: Agent) {
        Task {
            do {
                try await SupabaseService.shared.deleteAgent(id: agent.id)
                toasts.show("Collection deleted")
                await load()
            } catch {
                toasts.show(error.localizedDescription, type: .error)
            }
            agentToDelete = nil
        }
    }
}

// MARK: - Stat card

private struct StatCard: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hsl: 199, 89, 55, alpha: 0.16))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hsl: 199, 89, 55))
                }
            }
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
        }
        .padding(14)
        .frame(minHeight: 94)
        .background(Theme.card)
        .clipShape(.rect(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Feed card

private struct FeedCardView: View {
    let agent: Agent
    let accent: Color
    let counts: AgentItemCounts
    let onTap: () -> Void

    private var watchedPct: Int {
        guard counts.total > 0 else { return 0 }
        return Int((Double(counts.watched) / Double(counts.total) * 100).rounded())
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                Rectangle().fill(accent).frame(width: 4)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 14))
                            .foregroundStyle(accent)
                        Text(agent.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        if counts.total > 0 && counts.unwatched == 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))
                                Text("All caught up")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(Theme.success)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .overlay(Capsule().stroke(Theme.success, lineWidth: 1))
                        }
                    }

                    // Read-only here: the description is written or changed only
                    // when creating or editing the collection.
                    if let description = agent.description?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty {
                        Text(description)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                            .padding(.vertical, 4)
                    }

                    if counts.total > 0 {
                        HStack(spacing: 8) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color(hsl: 220, 20, 18))
                                    Capsule().fill(Theme.success)
                                        .frame(width: geo.size.width * CGFloat(watchedPct) / 100)
                                }
                            }
                            .frame(height: 5)
                            Text("\(watchedPct)%")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.success)
                                .frame(minWidth: 32, alignment: .trailing)
                        }
                        .padding(.top, 12)
                    } else {
                        Text("No items yet")
                            .font(.system(size: 12))
                            .italic()
                            .foregroundStyle(Theme.textMuted)
                            .padding(.top, 12)
                    }

                    HStack(spacing: 16) {
                        countChip(icon: "square.stack", iconColor: Theme.textSecondary, value: counts.total, valueColor: Theme.textPrimary)
                        countChip(icon: "checkmark.circle.fill", iconColor: Theme.success, value: counts.watched, valueColor: Theme.success)
                        countChip(icon: "circle", iconColor: Theme.textMuted, value: counts.unwatched, valueColor: Theme.textMuted)
                        countChip(icon: "clock", iconColor: Theme.warning, value: counts.watchLater, valueColor: Theme.warning)
                        Spacer()
                    }
                    .padding(.top, 12)
                }
                .padding(14)
            }
            .cardStyle(radius: 10)
            .padding(.bottom, 12)
        }
        .buttonStyle(.plain)
    }

    private func countChip(icon: String, iconColor: Color, value: Int, valueColor: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(iconColor)
            Text("\(value)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(valueColor)
                .monospacedDigit()
        }
    }
}

// MARK: - Agent card

private struct DashboardAgentCard: View {
    let agent: Agent
    let accent: Color
    let channelCount: Int
    let lastSuccessRun: Run?
    let isPending: Bool
    let anyPending: Bool
    let onRun: () -> Void
    let onDelete: () -> Void

    var body: some View {
        NavigationLink(value: AppRoute.agentDetail(agent.id)) {
            HStack(spacing: 0) {
                Rectangle().fill(accent).frame(width: 4)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "cpu")
                            .font(.system(size: 14))
                            .foregroundStyle(accent)
                        Text(agent.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Spacer()

                        Button(action: onRun) {
                            ZStack {
                                if isPending {
                                    ProgressView().controlSize(.small).tint(Theme.textSecondary)
                                } else {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                            .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                        .disabled(anyPending)

                        Menu {
                            NavigationLink(value: AppRoute.agentForm(agent.id)) {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive, action: onDelete) {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 36, height: 36)
                        }
                    }

                    if let description = agent.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                            .lineSpacing(3)
                    }

                    HStack(spacing: 10) {
                        HStack(spacing: 4) {
                            Image(systemName: "video")
                                .font(.system(size: 11))
                            Text("\(channelCount) channels")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(Theme.textSecondary)

                        if let time = agent.runTimeLocal, !time.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 11))
                                Text(time)
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.top, 12)

                    if let lastRun = lastSuccessRun {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                            Text(Format.relativeTime(lastRun.startedAt))
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(Color(hsl: 152, 69, 50))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hsl: 152, 69, 50, alpha: 0.15))
                        .clipShape(Capsule())
                        .padding(.top, 10)

                        if let newCount = lastRun.videosNewCount, newCount > 0 {
                            (Text("Found ")
                             + Text(Format.compactNumber(newCount)).fontWeight(.bold)
                             + Text(" new videos"))
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.top, 8)
                        }
                    }
                }
                .padding(14)
            }
            .cardStyle(radius: 10)
            .padding(.bottom, 12)
        }
        .buttonStyle(.plain)
    }
}


/// A dashboard section title that opens and closes the section below it, with
/// an optional action on the right ("View All").
private struct CollapsibleSectionHeader: View {
    let title: String
    var count: Int? = nil
    @Binding var isOpen: Bool
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
                withAnimation(.easeInOut(duration: 0.2)) { isOpen.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                    Text(title.uppercased())
                        .font(.system(size: 13, weight: .bold))
                        .kerning(0.6)
                    if let count {
                        Text("(\(count))")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textMuted)
                    }
                }
                .foregroundStyle(Theme.textSecondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(isOpen ? "Expanded" : "Collapsed")
            .accessibilityHint(isOpen ? "Collapses the section" : "Expands the section")
            Spacer()
            if let actionLabel, let action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .padding(.top, 26)
        .padding(.bottom, 12)
    }
}
