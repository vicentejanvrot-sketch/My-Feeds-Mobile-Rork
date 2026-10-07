import SwiftUI

struct AgentsView: View {
    @Environment(RunningOverlayStore.self) private var overlay

    @State private var agents: [Agent] = []
    @State private var isLoading = true
    @State private var isOffline = false

    private var sortedAgents: [Agent] {
        agents.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                if isOffline { offlineBanner }

                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .tint(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else if sortedAgents.isEmpty {
                    VStack(spacing: 6) {
                        Text("No collections yet")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Create a collection and it will appear here automatically.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .cardStyle(radius: 12)
                } else {
                    ForEach(Array(sortedAgents.enumerated()), id: \.element.id) { index, agent in
                        AgentListCard(
                            agent: agent,
                            accent: Theme.agentAccent(index),
                            isPending: overlay.pendingId == agent.id,
                            anyPending: overlay.pendingId != nil
                        ) {
                            Task { await overlay.run(agent: agent) }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
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
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Collections")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(agents.count) configured")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if !agents.isEmpty {
                Button {
                    let toRun = sortedAgents
                    Task { await overlay.runAll(agents: toRun) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                        Text("Run All")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(height: 40)
                    .frame(minWidth: 96)
                    .padding(.horizontal, 16)
                    .background(Theme.accentGradient)
                    .clipShape(.rect(cornerRadius: 10))
                }
                .disabled(overlay.pendingId != nil)
            }
        }
        .padding(.bottom, 20)
    }

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 13))
            Text("Offline — couldn't load latest collections.")
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
        do {
            let loaded = try await SupabaseService.shared.fetchAgents()
            agents = loaded
            isOffline = false
        } catch {
            // A cancelled load (tab switch) isn't being offline.
            if !error.isCancellation { isOffline = true }
        }
        isLoading = false
    }
}

private struct AgentListCard: View {
    let agent: Agent
    let accent: Color
    let isPending: Bool
    let anyPending: Bool
    let onRun: () -> Void

    var body: some View {
        NavigationLink(value: AppRoute.agentDetail(agent.id)) {
            HStack(spacing: 0) {
                Rectangle().fill(accent).frame(width: 4)

                VStack(alignment: .leading, spacing: 0) {
                    Text(agent.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)

                    if let description = agent.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                            .lineSpacing(3)
                            .padding(.top, 4)
                    }

                    HStack(spacing: 14) {
                        metaItem(icon: "clock", text: Agent.frequencyLabel(agent.scheduleFrequency))
                        if let time = agent.runTimeLocal, !time.isEmpty {
                            metaItem(icon: "envelope", text: time)
                        }
                        Spacer()
                    }
                    .padding(.top, 12)

                    Button(action: onRun) {
                        HStack(spacing: 6) {
                            if isPending {
                                ProgressView().controlSize(.small).tint(accent)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 13))
                            }
                            Text("Run Now")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(anyPending && !isPending ? Color.white.opacity(0.3) : accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(
                                    anyPending && !isPending ? Color.white.opacity(0.18) : accent,
                                    lineWidth: 1.5
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(anyPending)
                    .padding(.top, 16)
                }
                .padding(16)
            }
            .cardStyle(radius: 12)
            .padding(.bottom, 14)
        }
        .buttonStyle(.plain)
    }

    private func metaItem(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(text)
                .font(.system(size: 12))
        }
        .foregroundStyle(Theme.textSecondary)
    }
}
