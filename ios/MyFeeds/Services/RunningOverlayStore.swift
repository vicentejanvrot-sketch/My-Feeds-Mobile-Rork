import SwiftUI
import Observation

/// Global state + orchestration for the full-screen agent-run overlay.
/// Mirrors the companion apps (expo/lib/runAgent.ts): insert run row → show
/// overlay → invoke `run-agent` and use its reply. The run row is polled only
/// when the reply didn't say how the run ended, and never for longer than
/// `maxWait`.
@Observable
final class RunningOverlayStore {
    enum Phase: Equatable {
        case running
        case success(message: String)
        case error(message: String)
    }

    struct OverlayState: Equatable {
        var agentName: String
        var runId: String
        var phase: Phase
        var channelsTotal: Int = 0
        var channelsScanned: Int = 0
        var currentChannelName: String?
    }

    var state: OverlayState?
    /// Agent id currently running ("all" during Run All).
    var pendingId: String?
    /// Incremented after each finished run so screens can refetch.
    var runCompletionCounter = 0

    var isVisible: Bool { state != nil }

    func dismiss() {
        state = nil
    }

    /// Run a single agent end-to-end.
    func run(agent: Agent) async {
        guard pendingId == nil else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        pendingId = agent.id
        defer {
            pendingId = nil
            runCompletionCounter += 1
        }
        await runInternal(agent: agent)
    }

    /// Result of one agent run inside Run All.
    nonisolated private struct BatchOutcome: Sendable {
        let agentName: String
        let failed: Bool
        let newCount: Int
    }

    /// Run every agent at the same time, like the web app. Running them one
    /// after another made Run All take the sum of every agent's duration.
    /// Per-agent failures don't stop the others.
    func runAll(agents: [Agent]) async {
        guard pendingId == nil, !agents.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        pendingId = "all"
        defer {
            pendingId = nil
            runCompletionCounter += 1
        }

        let label = String(localized: "All collections (\(agents.count))", bundle: .appStrings)
        state = OverlayState(
            agentName: label, runId: Self.batchRunId, phase: .running,
            channelsTotal: agents.count, channelsScanned: 0, currentChannelName: nil
        )

        var finished = 0
        var newTotal = 0
        var failedNames: [String] = []
        await withTaskGroup(of: BatchOutcome.self) { group in
            for agent in agents {
                group.addTask { await self.runQuiet(agent: agent) }
            }
            for await outcome in group {
                finished += 1
                if outcome.failed {
                    failedNames.append(outcome.agentName)
                } else {
                    newTotal += outcome.newCount
                }
                state?.channelsScanned = finished
                state?.currentChannelName = String(localized: "\(outcome.agentName) finished", bundle: .appStrings)
            }
        }

        let found = newTotal > 0 ? String(localized: "Found \(newTotal) new videos", bundle: .appStrings) : String(localized: "No new videos found", bundle: .appStrings)
        if failedNames.isEmpty {
            state = OverlayState(agentName: label, runId: Self.batchRunId, phase: .success(message: found))
            try? await Task.sleep(for: .seconds(2.5))
            if case .success = state?.phase { state = nil }
        } else {
            let message = String(localized: "\(found). Failed: \(failedNames.formatted(.list(type: .and)))", bundle: .appStrings)
            state = OverlayState(agentName: label, runId: Self.batchRunId, phase: .error(message: message))
            await holdThenClearIfError(seconds: 4)
        }
    }

    /// Marks the overlay as showing Run All progress (agents, not channels).
    static let batchRunId = "all"

    /// How one run ended.
    nonisolated private enum RunOutcome: Sendable {
        case finished(newCount: Int, partial: Bool)
        /// The collection has no sources turned on.
        case skipped
        case failed(message: String)
    }

    /// Supabase stops an edge function after 400 seconds. A run still
    /// "running" after this long is never going to finish, so stop waiting.
    private static let maxWait: Duration = .seconds(420)

    /// Start one agent run and wait for it to finish without touching the overlay.
    private func runQuiet(agent: Agent) async -> BatchOutcome {
        guard let run = try? await SupabaseService.shared.startRun(agentId: agent.id) else {
            return BatchOutcome(agentName: agent.name, failed: true, newCount: 0)
        }
        switch await runAndWait(agentId: agent.id, runId: run.id) {
        case .finished(let newCount, _):
            return BatchOutcome(agentName: agent.name, failed: false, newCount: newCount)
        case .skipped:
            // Nothing to scan isn't a failure; Run All just moves on.
            return BatchOutcome(agentName: agent.name, failed: false, newCount: 0)
        case .failed:
            return BatchOutcome(agentName: agent.name, failed: true, newCount: 0)
        }
    }

    /// Invoke run-agent for an existing run row and wait until the run ends.
    ///
    /// run-agent does the whole scan before it replies. The app used to ignore
    /// the reply and poll the run row with no limit, and two things left that
    /// row "running" for good, so Run All never finished: a collection with no
    /// sources turned on (run-agent logs its own failed run instead) and a run
    /// whose edge function died before finishing.
    /// `onProgress` gets the run row each time it's read while still running.
    private func runAndWait(agentId: String, runId: String, onProgress: ((Run) -> Void)? = nil) async -> RunOutcome {
        let service = SupabaseService.shared
        let clock = ContinuousClock()
        let started = clock.now

        do {
            let reply = try await service.invokeRunAgent(agentId: agentId, runId: runId)
            if reply.skipped == true {
                // run-agent already logged a failed run for it, so drop the
                // row the app made instead of leaving it "running".
                try? await service.deleteRun(id: runId)
                return .skipped
            }
            if reply.status == "success" || reply.status == "partial" {
                return .finished(newCount: reply.videosNew ?? 0, partial: reply.status == "partial")
            }
            // Any other reply: read the run row below.
        } catch {
            if !SupabaseService.runMayStillBeRunning(after: error) {
                let message = extractEdgeErrorMessage(error)
                try? await service.markRunFailed(runId: runId, message: message)
                return .failed(message: message)
            }
        }

        while !Task.isCancelled, clock.now - started < Self.maxWait {
            if let current = try? await service.fetchRun(id: runId) {
                switch current.runStatus {
                case .success:
                    return .finished(newCount: current.videosNewCount ?? 0, partial: false)
                case .partial:
                    return .finished(newCount: current.videosNewCount ?? 0, partial: true)
                case .failed, .cancelled:
                    return .failed(message: current.errorSummary ?? String(localized: "An unknown error occurred", bundle: .appStrings))
                case .running:
                    onProgress?(current)
                }
            }
            try? await Task.sleep(for: .seconds(1.5))
        }

        let message = String(localized: "This collection took too long and was stopped", bundle: .appStrings)
        try? await service.markRunFailed(runId: runId, message: message)
        return .failed(message: message)
    }

    private func runInternal(agent: Agent) async {
        let run: Run
        do {
            run = try await SupabaseService.shared.startRun(agentId: agent.id)
        } catch {
            state = OverlayState(agentName: agent.name, runId: "", phase: .error(message: error.localizedDescription))
            await holdThenClearIfError(seconds: 4)
            return
        }

        state = OverlayState(agentName: agent.name, runId: run.id, phase: .running)

        let outcome = await runAndWait(agentId: agent.id, runId: run.id) { [weak self] current in
            guard let self, self.state?.runId == run.id else { return }
            self.state?.channelsTotal = current.channelsTotal ?? 0
            self.state?.channelsScanned = current.channelsScanned ?? 0
            self.state?.currentChannelName = current.currentChannelName
        }
        switch outcome {
        case .finished(let count, let partial):
            let message: String
            if partial {
                message = count > 0
                    ? String(localized: "Found \(count) new videos (some channels couldn't be scanned)", bundle: .appStrings)
                    : String(localized: "Scan finished — some channels couldn't be scanned.", bundle: .appStrings)
            } else {
                message = count > 0 ? String(localized: "Found \(count) new videos", bundle: .appStrings) : String(localized: "No new videos found", bundle: .appStrings)
            }
            state = OverlayState(agentName: agent.name, runId: run.id, phase: .success(message: message))
            try? await Task.sleep(for: .seconds(2.5))
            if case .success = state?.phase { state = nil }
        case .skipped:
            let message = String(localized: "This collection has no sources turned on", bundle: .appStrings)
            state = OverlayState(agentName: agent.name, runId: run.id, phase: .error(message: message))
            await holdThenClearIfError(seconds: 4)
        case .failed(let message):
            state = OverlayState(agentName: agent.name, runId: run.id, phase: .error(message: message))
            await holdThenClearIfError(seconds: 4)
        }
    }

    private func holdThenClearIfError(seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
        if case .error = state?.phase { state = nil }
    }

    private func extractEdgeErrorMessage(_ error: Error) -> String {
        let message = error.localizedDescription
        return message.isEmpty ? String(localized: "Something went wrong. Try again.", bundle: .appStrings) : message
    }
}

/// Full-screen overlay view shown during agent runs.
struct RunningOverlayView: View {
    @Environment(RunningOverlayStore.self) private var overlay
    @State private var pulse = false

    var body: some View {
        if let state = overlay.state {
            ZStack {
                Rectangle()
                    .fill(.black.opacity(0.75))
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    card(for: state)
                    if case .running = state.phase {
                        EmptyView()
                    } else {
                        Text("Tap anywhere to dismiss")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 24)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if case .running = state.phase { return }
                overlay.dismiss()
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private func card(for state: RunningOverlayStore.OverlayState) -> some View {
        VStack(spacing: 16) {
            switch state.phase {
            case .running:
                ZStack {
                    Circle()
                        .stroke(.white.opacity(pulse ? 0 : 0.5), lineWidth: 2)
                        .frame(width: 56, height: 56)
                        .scaleEffect(pulse ? 1.5 : 1)
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
                Text("🚀 Running \"\(state.agentName)\"")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                if state.channelsTotal > 0 {
                    VStack(spacing: 8) {
                        HStack {
                            Text(state.runId == RunningOverlayStore.batchRunId ? String(localized: "Collections finished", bundle: .appStrings) : String(localized: "Scanning channels", bundle: .appStrings))
                            Spacer()
                            Text(verbatim: "\(state.channelsScanned) / \(state.channelsTotal)")
                                .monospacedDigit()
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.2))
                                Capsule().fill(.white)
                                    .frame(width: geo.size.width * progress(state))
                            }
                        }
                        .frame(height: 6)

                        if let channel = state.currentChannelName {
                            HStack(spacing: 6) {
                                Image(systemName: "tv")
                                    .font(.system(size: 12))
                                Text(channel)
                                    .lineLimit(1)
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                } else {
                    Text("Initializing…")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.85))
                }
            case .success(let message):
                ZStack {
                    Circle().fill(.white).frame(width: 64, height: 64)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color(hsl: 152, 69, 40))
                }
                Text("☑️ \"\(state.agentName)\" Completed!")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            case .error(let message):
                Text("❌ \"\(state.agentName)\" Failed")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(5)
            }
        }
        .padding(24)
        .frame(maxWidth: 380)
        .background(cardColor(for: state.phase))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .white.opacity(0.15), radius: 24)
    }

    private func progress(_ state: RunningOverlayStore.OverlayState) -> CGFloat {
        guard state.channelsTotal > 0 else { return 0 }
        return CGFloat(state.channelsScanned) / CGFloat(state.channelsTotal)
    }

    private func cardColor(for phase: RunningOverlayStore.Phase) -> Color {
        switch phase {
        case .running: return Color(hsl: 199, 89, 48)
        case .success: return Color(hsl: 152, 69, 50)
        case .error: return Color(hsl: 0, 72, 55)
        }
    }
}
