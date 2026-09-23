import Foundation

/// Computed watch-time statistics matching the companion apps.
nonisolated struct WatchTimeStatsData: Sendable {
    struct DailyBucket: Identifiable, Sendable {
        let id: String // yyyy-MM-dd
        let date: Date
        let label: String // MMM d
        var watchedSeconds = 0
        var unwatchedSeconds = 0
        var watchedCount = 0
        var unwatchedCount = 0
    }

    struct ChannelBucket: Identifiable, Sendable {
        let id: String
        let name: String
        var watchedSeconds = 0
        var unwatchedSeconds = 0
        var watchedCount = 0
        var totalCount = 0
    }

    struct AgentBucket: Identifiable, Sendable {
        let id: String
        let name: String
        var watchedSeconds = 0
        var unwatchedSeconds = 0
        var watchedCount = 0
        var totalCount = 0
        var channels: [ChannelBucket] = []
    }

    struct WeeklyComparison: Sendable {
        var thisWeekWatchedSeconds = 0
        var thisWeekWatchedCount = 0
        var thisWeekTotalCount = 0
        var lastWeekWatchedSeconds = 0
        var lastWeekWatchedCount = 0
        var lastWeekTotalCount = 0
        var watchedTimeDiffPct = 0
    }

    var totalWatchedSeconds = 0
    var totalUnwatchedSeconds = 0
    var totalWatchedCount = 0
    var totalCount = 0
    var dailyTrend: [DailyBucket] = []
    var byAgent: [AgentBucket] = []
    var weekly = WeeklyComparison()
}

enum StatsPeriod: String, CaseIterable {
    case week = "7 days"
    case month = "30 days"
    case all = "All time"

    var days: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .all: return nil
        }
    }
}

/// Pure computation of watch-time stats from raw rows.
nonisolated enum WatchTimeStatsBuilder {
    /// "Watched" = watched or liked.
    private static func isWatched(_ status: ItemStatus?) -> Bool {
        status == .watched || status == .liked
    }

    /// Day a video counts toward, matching the web app: watched/liked videos
    /// count on the day they were watched, everything else on its publish date.
    private static func bucketDate(_ item: StatsItem) -> Date? {
        if isWatched(item.userStatus) {
            return Format.parseDate(item.watchedAt ?? item.publishedAt ?? item.createdAt)
        }
        return Format.parseDate(item.publishedAt ?? item.createdAt)
    }

    static func build(
        items: [StatsItem],
        agentNames: [String: String],
        durations: [String: Int],
        period: StatsPeriod,
        now: Date = Date()
    ) -> WatchTimeStatsData {
        var data = WatchTimeStatsData()
        let calendar = Calendar.current

        // Totals
        for item in items {
            let duration = durations[item.id] ?? 0
            data.totalCount += 1
            if isWatched(item.userStatus) {
                data.totalWatchedCount += 1
                data.totalWatchedSeconds += duration
            } else {
                data.totalUnwatchedSeconds += duration
            }
        }

        // Date range for the daily trend. Same window as the web app:
        // now minus N days, with one bar per calendar day in that window.
        let startOfToday = calendar.startOfDay(for: now)
        var startDate: Date
        if let days = period.days {
            let windowStart = calendar.date(byAdding: .day, value: -days, to: now) ?? now
            startDate = calendar.startOfDay(for: windowStart)
        } else {
            let earliest = items
                .compactMap { bucketDate($0) }
                .min() ?? startOfToday
            startDate = calendar.startOfDay(for: earliest)
        }

        // Pre-initialize every day in range so the chart has no gaps
        let dayKeyFormatter = DateFormatter()
        dayKeyFormatter.dateFormat = "yyyy-MM-dd"
        let labelFormatter = DateFormatter()
        labelFormatter.dateFormat = "MMM d"

        var buckets: [String: WatchTimeStatsData.DailyBucket] = [:]
        var cursor = startDate
        var dayCount = 0
        while cursor <= startOfToday && dayCount < 730 {
            let key = dayKeyFormatter.string(from: cursor)
            buckets[key] = WatchTimeStatsData.DailyBucket(
                id: key, date: cursor, label: labelFormatter.string(from: cursor)
            )
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86400)
            dayCount += 1
        }

        for item in items {
            guard let itemDate = bucketDate(item) else { continue }
            let key = dayKeyFormatter.string(from: itemDate)
            guard var bucket = buckets[key] else { continue }
            let duration = durations[item.id] ?? 0
            if isWatched(item.userStatus) {
                bucket.watchedSeconds += duration
                bucket.watchedCount += 1
            } else {
                bucket.unwatchedSeconds += duration
                bucket.unwatchedCount += 1
            }
            buckets[key] = bucket
        }
        data.dailyTrend = buckets.values.sorted { $0.date < $1.date }

        // Weekly comparison (Monday-based). Same rules as the web app: each
        // video counts on the same day it counts toward in the daily trend.
        var mondayCalendar = Calendar(identifier: .iso8601)
        mondayCalendar.firstWeekday = 2
        let thisWeekStart = mondayCalendar.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfToday
        let lastWeekStart = mondayCalendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? thisWeekStart
        let lastWeekEnd = calendar.date(byAdding: .day, value: -1, to: thisWeekStart) ?? thisWeekStart

        for item in items {
            guard let itemDate = bucketDate(item) else { continue }
            let duration = durations[item.id] ?? 0
            if itemDate >= thisWeekStart {
                data.weekly.thisWeekTotalCount += 1
                if isWatched(item.userStatus) {
                    data.weekly.thisWeekWatchedCount += 1
                    data.weekly.thisWeekWatchedSeconds += duration
                }
            } else if itemDate >= lastWeekStart && itemDate <= lastWeekEnd {
                data.weekly.lastWeekTotalCount += 1
                if isWatched(item.userStatus) {
                    data.weekly.lastWeekWatchedCount += 1
                    data.weekly.lastWeekWatchedSeconds += duration
                }
            }
        }
        if data.weekly.lastWeekWatchedSeconds > 0 {
            let diff = Double(data.weekly.thisWeekWatchedSeconds - data.weekly.lastWeekWatchedSeconds)
                / Double(data.weekly.lastWeekWatchedSeconds) * 100
            data.weekly.watchedTimeDiffPct = Int(diff.rounded())
        } else {
            data.weekly.watchedTimeDiffPct = data.weekly.thisWeekWatchedSeconds > 0 ? 100 : 0
        }

        // By agent with nested channels
        var agentBuckets: [String: WatchTimeStatsData.AgentBucket] = [:]
        var channelBuckets: [String: [String: WatchTimeStatsData.ChannelBucket]] = [:]

        for item in items {
            let agentId = item.agentId ?? "unknown"
            let agentName = agentNames[agentId] ?? "Unknown Agent"
            var agent = agentBuckets[agentId] ?? WatchTimeStatsData.AgentBucket(id: agentId, name: agentName)
            let duration = durations[item.id] ?? 0
            agent.totalCount += 1
            if isWatched(item.userStatus) {
                agent.watchedCount += 1
                agent.watchedSeconds += duration
            } else {
                agent.unwatchedSeconds += duration
            }
            agentBuckets[agentId] = agent

            let channelId = item.channelId ?? "unknown"
            var channel = channelBuckets[agentId]?[channelId]
                ?? WatchTimeStatsData.ChannelBucket(id: channelId, name: item.channelName ?? "Unknown Channel")
            channel.totalCount += 1
            if isWatched(item.userStatus) {
                channel.watchedCount += 1
                channel.watchedSeconds += duration
            } else {
                channel.unwatchedSeconds += duration
            }
            channelBuckets[agentId, default: [:]][channelId] = channel
        }

        data.byAgent = agentBuckets.values
            .map { agent in
                var copy = agent
                // Same order as the web app: most total time first.
                copy.channels = (channelBuckets[agent.id]?.values.map { $0 } ?? [])
                    .sorted {
                        ($0.watchedSeconds + $0.unwatchedSeconds) > ($1.watchedSeconds + $1.unwatchedSeconds)
                    }
                return copy
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return data
    }
}
