import SwiftUI

struct HistoryView: View {
    @Environment(ToastCenter.self) private var toasts
    @Environment(RunningOverlayStore.self) private var overlay

    @State private var runs: [Run] = []
    @State private var agents: [String: Agent] = [:]
    @State private var channelsByAgent: [String: [Channel]] = [:]
    @State private var isLoading = true
    @State private var isOffline = false
    @State private var expandedRuns: Set<String> = []
    @State private var cancellingRunId: String?
    @State private var isDeletingAll = false
    @State private var showDeleteAllConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                if isOffline { offlineBanner }

                if isLoading && runs.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(Theme.accent)
                        Text("Loading runs…")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 80)
                } else if runs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.textMuted)
                        Text("No runs yet")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("When you run a collection, its results will appear here.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                    .cardStyle(radius: 16)
                    .padding(.top, 60)
                } else {
                    ForEach(runs) { run in
                        RunCard(
                            run: run,
                            agent: agents[run.agentId],
                            channels: channelsByAgent[run.agentId] ?? [],
                            isExpanded: expandedRuns.contains(run.id),
                            isCancelling: cancellingRunId == run.id,
                            onToggleExpand: {
                                if expandedRuns.contains(run.id) {
                                    expandedRuns.remove(run.id)
                                } else {
                                    expandedRuns.insert(run.id)
                                }
                            },
                            onCancel: { cancelRun(run) }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 40)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await load() }
        .task { await load() }
        .onChange(of: overlay.runCompletionCounter) {
            Task { await load() }
        }
        .alert("Delete Run History", isPresented: $showDeleteAllConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) { deleteAll() }
        } message: {
            Text("This clears the Run History list only. Your videos, feed, and statistics are kept. This cannot be undone.")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 26))
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Run History")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                Text(runs.isEmpty
                     ? "Timeline of collection activity"
                     : "\(runs.count) run\(runs.count == 1 ? "" : "s") across all collections")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if !runs.isEmpty {
                Button {
                    showDeleteAllConfirm = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                        Text(isDeletingAll ? "Deleting…" : "Delete All")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Theme.destructive)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.destructive, lineWidth: 1)
                    )
                    .opacity(isDeletingAll ? 0.5 : 1)
                }
                .disabled(isDeletingAll)
            }
        }
        .padding(.bottom, 16)
    }

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 13))
            Text("Offline — couldn't load latest run history.")
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

    private func load() async {
        let service = SupabaseService.shared
        do {
            async let runsTask = service.fetchRuns(limit: 100)
            async let agentsTask = service.fetchAgents()
            async let channelsTask = service.fetchAllChannels()
            let (loadedRuns, loadedAgents, loadedChannels) = try await (runsTask, agentsTask, channelsTask)
            runs = loadedRuns
            agents = Dictionary(uniqueKeysWithValues: loadedAgents.map { ($0.id, $0) })
            channelsByAgent = Dictionary(grouping: loadedChannels, by: \.agentId)
            isOffline = false
        } catch {
            // A cancelled load (tab switch) isn't being offline.
            if !error.isCancellation { isOffline = true }
        }
        isLoading = false
    }

    private func cancelRun(_ run: Run) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        cancellingRunId = run.id
        Task {
            do {
                try await SupabaseService.shared.cancelRun(runId: run.id)
                toasts.show("Run cancelled", type: .info)
                await load()
            } catch {
                toasts.show("Failed to cancel run", type: .error)
            }
            cancellingRunId = nil
        }
    }

    private func deleteAll() {
        isDeletingAll = true
        let ids = runs.map(\.id)
        Task {
            do {
                try await SupabaseService.shared.clearRuns(ids: ids)
                toasts.show("Run history deleted")
                await load()
            } catch {
                toasts.show("Failed to delete run history", type: .error)
            }
            isDeletingAll = false
        }
    }
}

// MARK: - Run card

private struct RunCard: View {
    let run: Run
    let agent: Agent?
    let channels: [Channel]
    let isExpanded: Bool
    let isCancelling: Bool
    let onToggleExpand: () -> Void
    let onCancel: () -> Void

    private var showChannelToggle: Bool {
        [RunStatus.partial, .failed, .cancelled].contains(run.runStatus) && !channels.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                NavigationLink(value: AppRoute.agentDetail(run.agentId)) {
                    Text(agent?.name ?? "Unknown Collection")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                Spacer()
                StatusPill(status: run.runStatus, showIcon: true)
            }

            Text(Format.runTimestamp(run.startedAt))
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 6)

            statGrid
                .padding(.top, 12)

            summaryBox

            if showChannelToggle {
                Button(action: onToggleExpand) {
                    HStack(spacing: 6) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                        Text(isExpanded ? "Hide channels" : "Channels (\(channels.count))")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Theme.input)
                    .clipShape(.rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(.top, 12)

                if isExpanded {
                    VStack(spacing: 0) {
                        ForEach(channels) { channel in
                            channelRow(channel)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.input)
                    .clipShape(.rect(cornerRadius: 8))
                    .padding(.top, 8)
                }
            }

            if run.runStatus == .running {
                Button(action: onCancel) {
                    HStack(spacing: 6) {
                        if isCancelling {
                            ProgressView().controlSize(.small).tint(Theme.destructive)
                            Text("Cancelling…")
                                .font(.system(size: 13, weight: .semibold))
                        } else {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Cancel Run")
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .foregroundStyle(Theme.destructive)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.destructive, lineWidth: 1)
                    )
                    .opacity(isCancelling ? 0.5 : 1)
                }
                .buttonStyle(.plain)
                .disabled(isCancelling)
                .padding(.top, 12)
            }
        }
        .padding(16)
        .cardStyle(radius: 14)
        .padding(.bottom, 12)
    }

    private var statGrid: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                statRow(label: "Duration:", value: Format.runDuration(started: run.startedAt, finished: run.finishedAt))
                statRow(label: "New:", value: run.videosNewCount.map(String.init) ?? "—")
                statRow(label: "Channels:", value: "\(run.channelsScanned ?? 0) / \(run.channelsTotal ?? 0)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                statRow(label: "Found:", value: run.videosFoundCount.map(String.init) ?? "—")
                statRow(label: "Enriched:", value: run.videosEnrichedCount.map(String.init) ?? "—")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.border).frame(height: 0.5)
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var summaryBox: some View {
        if let summary = run.errorSummary, !summary.isEmpty {
            switch run.runStatus {
            case .partial:
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 12))
                        Text("Completed with issues")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Theme.warning)
                    Text(summary)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.warning.opacity(0.85))
                        .lineLimit(3)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255).opacity(0.12))
                .clipShape(.rect(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255).opacity(0.25), lineWidth: 1)
                )
                .padding(.top, 12)
            case .failed:
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 12))
                    Text(summary)
                        .font(.system(size: 12))
                        .lineLimit(3)
                }
                .foregroundStyle(Theme.destructive)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.destructiveBg)
                .clipShape(.rect(cornerRadius: 8))
                .padding(.top, 12)
            case .cancelled:
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "nosign")
                        .font(.system(size: 12))
                    Text(summary)
                        .font(.system(size: 12))
                        .lineLimit(3)
                }
                .foregroundStyle(Theme.textMuted)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 96 / 255, green: 105 / 255, blue: 119 / 255).opacity(0.15))
                .clipShape(.rect(cornerRadius: 8))
                .padding(.top, 12)
            default:
                EmptyView()
            }
        }
    }

    private func channelRow(_ channel: Channel) -> some View {
        let scannedDuringRun: Bool = {
            guard let scanned = Format.parseDate(channel.lastScannedAt),
                  let started = Format.parseDate(run.startedAt) else { return false }
            return scanned >= started
        }()

        return HStack(spacing: 8) {
            Circle()
                .fill(scannedDuringRun ? Theme.success : Theme.textMuted)
                .frame(width: 6, height: 6)
            Text(channel.displayName)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Spacer()
            Text(channel.lastScannedAt != nil ? Format.timeAgo(channel.lastScannedAt) : "Never")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 0.5)
        }
    }
}
