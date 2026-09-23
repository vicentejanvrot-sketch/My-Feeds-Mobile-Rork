import SwiftUI
import Charts

/// Collapsible "Watch Time Statistics" section embedded on the Dashboard.
struct WatchTimeStatsSection: View {
    @State private var isExpanded = false
    @State private var period: StatsPeriod = .week
    @State private var chartMode: ChartMode = .bar
    @State private var stats: WatchTimeStatsData?
    @State private var isLoading = false
    @State private var expandedAgents: Set<String> = []
    @State private var agentColorIndex: [String: Int] = [:]

    enum ChartMode: String, CaseIterable {
        case bar = "Bar"
        case area = "Area"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                if isExpanded && stats == nil { Task { await load() } }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.accent)
                    Text("WATCH TIME STATISTICS")
                        .font(.system(size: 13, weight: .bold))
                        .kerning(0.6)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 26)
                .padding(.bottom, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    periodSelector

                    if isLoading {
                        ProgressView()
                            .tint(Theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else if let stats, stats.totalCount > 0 {
                        totalContentCard(stats)
                        weeklyComparisonCard(stats)
                        dailyTrendCard(stats)
                        byAgentCard(stats)
                        detailedBreakdown(stats)
                    } else {
                        Text("Detailed watch-time analytics will appear here as data accumulates.")
                            .font(.system(size: 13))
                            .italic()
                            .foregroundStyle(Theme.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }
                }
                .padding(14)
                .cardStyle(radius: 10)
            }
        }
        .onChange(of: period) {
            Task { await load() }
        }
    }

    // MARK: - Subsections

    private var periodSelector: some View {
        HStack(spacing: 8) {
            ForEach(StatsPeriod.allCases, id: \.self) { option in
                Button {
                    period = option
                } label: {
                    Text(option.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(period == option ? .white : Theme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(period == option ? Theme.accent : Theme.input)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func totalContentCard(_ stats: WatchTimeStatsData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(stats.totalWatchedCount) of \(stats.totalCount) videos")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
            Text(Format.watchDuration(stats.totalWatchedSeconds + stats.totalUnwatchedSeconds))
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hsl: 220, 20, 18))
                    Capsule().fill(Theme.success)
                        .frame(width: geo.size.width * watchedFraction(stats))
                }
            }
            .frame(height: 5)

            HStack(spacing: 6) {
                Image(systemName: "eye")
                    .font(.system(size: 12))
                Text("Watched \(Format.watchDuration(stats.totalWatchedSeconds)) (\(stats.totalWatchedCount) videos)")
                    .font(.system(size: 12))
            }
            .foregroundStyle(Theme.success)

            HStack(spacing: 6) {
                Image(systemName: "eye.slash")
                    .font(.system(size: 12))
                Text("Not Watched \(Format.watchDuration(stats.totalUnwatchedSeconds)) (\(stats.totalCount - stats.totalWatchedCount) videos)")
                    .font(.system(size: 12))
            }
            .foregroundStyle(Theme.textMuted)
        }
        .padding(12)
        .background(Theme.input.opacity(0.5))
        .clipShape(.rect(cornerRadius: 8))
    }

    private func watchedFraction(_ stats: WatchTimeStatsData) -> CGFloat {
        guard stats.totalCount > 0 else { return 0 }
        return CGFloat(stats.totalWatchedCount) / CGFloat(stats.totalCount)
    }

    private func weeklyComparisonCard(_ stats: WatchTimeStatsData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.accent)
                Text("Weekly Comparison")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }

            HStack(alignment: .top, spacing: 16) {
                weekColumn(
                    title: "THIS WEEK",
                    seconds: stats.weekly.thisWeekWatchedSeconds,
                    watched: stats.weekly.thisWeekWatchedCount,
                    total: stats.weekly.thisWeekTotalCount,
                    valueColor: Theme.success
                )
                weekColumn(
                    title: "LAST WEEK",
                    seconds: stats.weekly.lastWeekWatchedSeconds,
                    watched: stats.weekly.lastWeekWatchedCount,
                    total: stats.weekly.lastWeekTotalCount,
                    valueColor: Theme.textMuted
                )
            }

            if stats.weekly.watchedTimeDiffPct != 0 {
                let up = stats.weekly.watchedTimeDiffPct > 0
                Text("\(up ? "↑" : "↓") \(abs(stats.weekly.watchedTimeDiffPct))%")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(up ? Theme.success : Theme.destructive)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .background(Theme.input.opacity(0.5))
        .clipShape(.rect(cornerRadius: 8))
    }

    private func weekColumn(title: String, seconds: Int, watched: Int, total: Int, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .kerning(0.5)
                .foregroundStyle(Theme.textMuted)
            Text(Format.watchDuration(seconds))
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(valueColor)
            Text("\(watched) of \(total) videos watched")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hsl: 220, 20, 18))
                    Capsule().fill(valueColor)
                        .frame(width: total > 0 ? geo.size.width * CGFloat(watched) / CGFloat(total) : 0)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dailyTrendCard(_ stats: WatchTimeStatsData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.accent)
                    Text("Daily Trend")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                HStack(spacing: 4) {
                    ForEach(ChartMode.allCases, id: \.self) { mode in
                        Button {
                            chartMode = mode
                        } label: {
                            Text(mode.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(chartMode == mode ? .white : Theme.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(chartMode == mode ? Theme.accent : Theme.input)
                                .clipShape(.rect(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 14) {
                legendDot(color: Theme.success, label: "Watched")
                legendDot(color: Theme.warning, label: "Not Watched")
            }

            chart(stats)
                .frame(height: 200)
        }
        .padding(12)
        .background(Theme.input.opacity(0.5))
        .clipShape(.rect(cornerRadius: 8))
    }

    @ViewBuilder
    private func chart(_ stats: WatchTimeStatsData) -> some View {
        let trend = stats.dailyTrend
        Chart {
            ForEach(trend) { bucket in
                if chartMode == .bar {
                    BarMark(
                        x: .value("Day", bucket.date, unit: .day),
                        y: .value("Hours", Double(bucket.watchedSeconds) / 3600)
                    )
                    .foregroundStyle(Theme.success)
                    BarMark(
                        x: .value("Day", bucket.date, unit: .day),
                        y: .value("Hours", Double(bucket.unwatchedSeconds) / 3600)
                    )
                    .foregroundStyle(Theme.warning.opacity(0.75))
                } else {
                    AreaMark(
                        x: .value("Day", bucket.date, unit: .day),
                        y: .value("Hours", Double(bucket.watchedSeconds + bucket.unwatchedSeconds) / 3600)
                    )
                    .foregroundStyle(Theme.warning.opacity(0.4))
                    AreaMark(
                        x: .value("Day", bucket.date, unit: .day),
                        y: .value("Hours", Double(bucket.watchedSeconds) / 3600),
                        series: .value("Series", "Watched")
                    )
                    .foregroundStyle(Theme.success.opacity(0.5))
                    LineMark(
                        x: .value("Day", bucket.date, unit: .day),
                        y: .value("Hours", Double(bucket.watchedSeconds) / 3600),
                        series: .value("Series", "Watched")
                    )
                    .foregroundStyle(Theme.success)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine().foregroundStyle(Theme.border.opacity(0.5))
                AxisValueLabel {
                    if let hours = value.as(Double.self) {
                        Text("\(Int(hours))h")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.textMuted)
                    }
                }
            }
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func byAgentCard(_ stats: WatchTimeStatsData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.pie")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.accent)
                Text("By Agent")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }

            HStack(alignment: .center, spacing: 16) {
                Chart(stats.byAgent) { agent in
                    SectorMark(
                        angle: .value("Time", max(agent.watchedSeconds + agent.unwatchedSeconds, 1)),
                        innerRadius: .ratio(0.62),
                        angularInset: 1.5
                    )
                    .foregroundStyle(agentColor(agent.id))
                }
                .frame(width: 150, height: 150)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(stats.byAgent) { agent in
                        HStack(spacing: 6) {
                            Circle().fill(agentColor(agent.id)).frame(width: 8, height: 8)
                            Text(agent.name)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
            }
        }
        .padding(12)
        .background(Theme.input.opacity(0.5))
        .clipShape(.rect(cornerRadius: 8))
    }

    private func detailedBreakdown(_ stats: WatchTimeStatsData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detailed Breakdown")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            ForEach(stats.byAgent) { agent in
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            if expandedAgents.contains(agent.id) {
                                expandedAgents.remove(agent.id)
                            } else {
                                expandedAgents.insert(agent.id)
                            }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: expandedAgents.contains(agent.id) ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Theme.textSecondary)
                                Text(agent.name)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text("(\(agent.watchedCount)/\(agent.totalCount))")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textMuted)
                                Spacer()
                            }
                            HStack(spacing: 12) {
                                HStack(spacing: 4) {
                                    Image(systemName: "eye")
                                        .font(.system(size: 10))
                                    Text(Format.watchDuration(agent.watchedSeconds))
                                        .font(.system(size: 11))
                                }
                                .foregroundStyle(Theme.success)
                                HStack(spacing: 4) {
                                    Image(systemName: "eye.slash")
                                        .font(.system(size: 10))
                                    Text(Format.watchDuration(agent.unwatchedSeconds))
                                        .font(.system(size: 11))
                                }
                                .foregroundStyle(Theme.textMuted)
                            }
                            progressBar(watched: agent.watchedCount, total: agent.totalCount, color: agentColor(agent.id))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if expandedAgents.contains(agent.id) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(agent.channels) { channel in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(channel.name)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Theme.textPrimary)
                                            .lineLimit(1)
                                        Spacer()
                                        Text("(\(channel.watchedCount)/\(channel.totalCount))")
                                            .font(.system(size: 10))
                                            .foregroundStyle(Theme.textMuted)
                                    }
                                    HStack(spacing: 12) {
                                        Text("Watched \(Format.watchDuration(channel.watchedSeconds))")
                                            .font(.system(size: 10))
                                            .foregroundStyle(Theme.success)
                                        Text("Not watched \(Format.watchDuration(channel.unwatchedSeconds))")
                                            .font(.system(size: 10))
                                            .foregroundStyle(Theme.textMuted)
                                    }
                                    progressBar(watched: channel.watchedCount, total: channel.totalCount, color: Theme.success)
                                }
                                .padding(.top, 8)
                                .overlay(alignment: .top) {
                                    Rectangle().fill(Theme.border).frame(height: 0.5)
                                }
                            }
                        }
                        .padding(.leading, 16)
                        .padding(.top, 8)
                    }
                }
                .padding(10)
                .background(Color(hsl: 220, 20, 10, alpha: 0.4))
                .clipShape(.rect(cornerRadius: 6))
                .overlay(alignment: .leading) {
                    UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 6)
                        .fill(agentColor(agent.id))
                        .frame(width: 3)
                }
            }
        }
    }

    private func progressBar(watched: Int, total: Int, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(hsl: 220, 20, 18))
                Capsule().fill(color)
                    .frame(width: total > 0 ? geo.size.width * CGFloat(watched) / CGFloat(total) : 0)
            }
        }
        .frame(height: 4)
    }

    private func agentColor(_ agentId: String) -> Color {
        Theme.agentAccent(agentColorIndex[agentId] ?? 0)
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        let service = SupabaseService.shared
        do {
            var startISO: String?
            if let days = period.days {
                // Same window as the web app: exactly N days back from now.
                let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
                startISO = ISO8601DateFormatter().string(from: start)
            }
            async let itemsTask = service.fetchStatsItems(startISO: startISO)
            async let agentsTask = service.fetchAgents()
            let (items, agents) = try await (itemsTask, agentsTask)
            let durations = try await service.fetchDurations(itemIds: items.map(\.id))
            let names = Dictionary(uniqueKeysWithValues: agents.map { ($0.id, $0.name) })

            // Agent color index follows the alphabetical agent list, matching companion apps
            let sorted = agents.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            agentColorIndex = Dictionary(uniqueKeysWithValues: sorted.enumerated().map { ($0.element.id, $0.offset) })

            stats = WatchTimeStatsBuilder.build(
                items: items, agentNames: names, durations: durations, period: period
            )
        } catch {
            stats = WatchTimeStatsData()
        }
        isLoading = false
    }
}
