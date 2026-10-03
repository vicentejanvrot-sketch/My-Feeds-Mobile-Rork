import Foundation
import Supabase

/// Central Supabase client + typed data access for the shared schema.
/// Tables already exist (created by the web app) — never recreate or alter them.
final class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        client = SupabaseClient(
            supabaseURL: URL(string: StaticConfig.supabaseURL)!,
            supabaseKey: StaticConfig.supabaseAnonKey,
            options: SupabaseClientOptions(
                db: .init(encoder: encoder, decoder: decoder),
                // Shared with the share extension (see SharedAuthStorage).
                auth: .init(storage: SharedAuthStorage())
            )
        )
    }

    private var db: PostgrestClient { client.schema("public") }

    // MARK: - Queries

    func fetchAgents() async throws -> [Agent] {
        try await db.from("agents").select().order("created_at", ascending: true).execute().value
    }

    func fetchAgent(id: String) async throws -> Agent {
        try await db.from("agents").select().eq("id", value: id).single().execute().value
    }

    func fetchChannels(agentId: String) async throws -> [Channel] {
        try await db.from("channels").select().eq("agent_id", value: agentId)
            .order("priority", ascending: false).execute().value
    }

    func fetchAllChannels() async throws -> [Channel] {
        try await db.from("channels").select().execute().value
    }

    func fetchRecipients(agentId: String) async throws -> [AgentRecipient] {
        try await db.from("agent_recipients").select().eq("agent_id", value: agentId)
            .order("created_at", ascending: true).execute().value
    }

    func fetchRuns(limit: Int = 50) async throws -> [Run] {
        try await db.from("runs").select().order("started_at", ascending: false)
            .limit(limit).execute().value
    }

    func fetchAgentRuns(agentId: String, limit: Int = 30) async throws -> [Run] {
        try await db.from("runs").select().eq("agent_id", value: agentId)
            .order("started_at", ascending: false).limit(limit).execute().value
    }

    func fetchRun(id: String) async throws -> Run {
        try await db.from("runs").select().eq("id", value: id).single().execute().value
    }

    /// Every feed item, newest first. The web app loads all of them (not just
    /// the newest few hundred), so the feed, its counts and its filters match
    /// only if this does too. Pass a limit to cap the total.
    func fetchFeedItems(limit: Int? = nil) async throws -> [FeedItem] {
        do {
            return try await fetchItemPages(columns: "*, item_analysis(*)", limit: limit)
        } catch {
            // A single malformed/legacy analysis row must not prevent the
            // native app from showing its videos. Retry with the base item
            // fields; FeedItem's optional analysis then falls back gracefully.
            var items = try await fetchItemPages(columns: "*", limit: limit)
            let durations = (try? await fetchDurations(itemIds: items.map(\.id))) ?? [:]
            for index in items.indices {
                items[index].resolvedDurationSeconds = durations[items[index].id]
            }
            return items
        }
    }

    /// Light rows for every feed item: only what the feed's filters, sorts and
    /// counts use, so the feed can show its first cards quickly. The full rows
    /// (pictures, post text, summaries) load 10 at a time with
    /// fetchFeedItems(ids:). Pages are read in parallel.
    func fetchFeedIndex() async throws -> [FeedItem] {
        let columns = "id, agent_id, video_id, title, channel_name, channel_id, published_at, user_status, platform, author_handle, item_analysis(id, views_at_analysis, duration_seconds, tags)"
        let total = try await db.from("items").select("id", head: true, count: .exact).execute().count ?? 0
        let pageSize = 1000
        // One extra page in case items arrive while this runs.
        let pageCount = total / pageSize + 1
        var pages: [Int: [FeedItem]] = [:]
        try await withThrowingTaskGroup(of: (Int, [FeedItem]).self) { group in
            for page in 0..<pageCount {
                group.addTask {
                    let svc = SupabaseService.shared
                    let rows = try await svc.fetchIndexPage(columns: columns, from: page * pageSize, to: page * pageSize + pageSize - 1)
                    return (page, rows)
                }
            }
            for try await (page, rows) in group { pages[page] = rows }
        }
        var seen = Set<String>()
        var all: [FeedItem] = []
        all.reserveCapacity(total)
        for page in pages.keys.sorted() {
            for row in pages[page] ?? [] where seen.insert(row.id).inserted { all.append(row) }
        }
        return all
    }

    private func fetchIndexPage(columns: String, from: Int, to: Int) async throws -> [FeedItem] {
        do {
            return try await db.from("items").select(columns)
                .order("published_at", ascending: false, nullsFirst: false)
                .order("id", ascending: true)
                .range(from: from, to: to)
                .execute().value
        } catch let error where error.isCancellation {
            throw error
        } catch {
            // A row that can't be read must not empty the feed: load the page
            // without the analysis (views, length, tags) instead.
            let plain = "id, agent_id, video_id, title, channel_name, channel_id, published_at, user_status, platform, author_handle"
            return try await db.from("items").select(plain)
                .order("published_at", ascending: false, nullsFirst: false)
                .order("id", ascending: true)
                .range(from: from, to: to)
                .execute().value
        }
    }

    /// The full rows for these items (the cards on screen).
    func fetchFeedItems(ids: [String]) async throws -> [FeedItem] {
        guard !ids.isEmpty else { return [] }
        do {
            return try await db.from("items").select("*, item_analysis(*)")
                .in("id", values: ids).execute().value
        } catch let error where error.isCancellation {
            throw error
        } catch {
            // A malformed analysis row must not hide the cards; load them without it.
            var rows: [FeedItem] = try await db.from("items").select().in("id", values: ids).execute().value
            let durations = (try? await fetchDurations(itemIds: rows.map(\.id))) ?? [:]
            for index in rows.indices { rows[index].resolvedDurationSeconds = durations[rows[index].id] }
            return rows
        }
    }

    /// The API returns at most 1,000 rows per request, so read page by page
    /// (in a stable order) until a short page comes back.
    private func fetchItemPages(columns: String, limit: Int?) async throws -> [FeedItem] {
        let pageSize = 1000
        var all: [FeedItem] = []
        while true {
            let from = all.count
            var to = from + pageSize - 1
            if let limit { to = min(to, limit - 1) }
            if to < from { break }
            let page: [FeedItem] = try await db.from("items").select(columns)
                .order("published_at", ascending: false, nullsFirst: false)
                .order("id", ascending: true)
                .range(from: from, to: to)
                .execute().value
            all.append(contentsOf: page)
            if page.count < to - from + 1 { break }
        }
        return all
    }

    /// One item with its analysis, for the post reader. Instagram's video and
    /// photo links expire a few days after the post was saved; expired ones are
    /// renewed before the post shows (see ExpiredMedia).
    func fetchItem(id: String) async throws -> FeedItem {
        let item: FeedItem
        do {
            item = try await db.from("items").select("*, item_analysis(*)")
                .eq("id", value: id).single().execute().value
        } catch {
            item = try await db.from("items").select().eq("id", value: id).single().execute().value
        }
        return await withFreshMedia(item)
    }

    /// Summary and transcript key moments for one video, for the player.
    func fetchItemAnalysis(itemId: String) async throws -> ItemAnalysis? {
        let rows: [ItemAnalysis] = try await db.from("item_analysis").select()
            .eq("item_id", value: itemId).limit(1).execute().value
        return rows.first
    }

    func fetchRunItemStatuses(runIds: [String]) async throws -> [RunItemStatus] {
        guard !runIds.isEmpty else { return [] }
        return try await db.from("items").select("run_id, user_status")
            .in("run_id", values: runIds).execute().value
    }

    func fetchUserSettings(userId: String) async throws -> UserSettings? {
        let rows: [UserSettings] = try await db.from("user_settings")
            .select("user_id, default_email, created_at, updated_at")
            .eq("user_id", value: userId).execute().value
        return rows.first
    }

    /// Five HEAD count queries per agent — no row data downloaded.
    func fetchAgentItemCounts(agentIds: [String]) async throws -> [String: AgentItemCounts] {
        var result: [String: AgentItemCounts] = [:]
        try await withThrowingTaskGroup(of: (String, AgentItemCounts).self) { group in
            for agentId in agentIds {
                group.addTask {
                    let svc = SupabaseService.shared
                    async let total = svc.countItems(agentId: agentId, status: nil, unwatched: false)
                    async let watched = svc.countItems(agentId: agentId, status: .watched, unwatched: false)
                    async let unwatched = svc.countItems(agentId: agentId, status: nil, unwatched: true)
                    async let later = svc.countItems(agentId: agentId, status: .watchLater, unwatched: false)
                    async let liked = svc.countItems(agentId: agentId, status: .liked, unwatched: false)
                    // Same as the web Dashboard: liked items count as watched.
                    let likedCount = try await liked
                    let counts = try await AgentItemCounts(
                        total: total, watched: watched + likedCount, unwatched: unwatched,
                        watchLater: later, liked: likedCount
                    )
                    return (agentId, counts)
                }
            }
            for try await (agentId, counts) in group {
                result[agentId] = counts
            }
        }
        return result
    }

    private func countItems(agentId: String, status: ItemStatus?, unwatched: Bool) async throws -> Int {
        var query = db.from("items").select("*", head: true, count: .exact)
            .eq("agent_id", value: agentId)
        if unwatched {
            query = query.or("user_status.is.null,user_status.eq.not_watched")
        } else if let status {
            query = query.eq("user_status", value: status.rawValue)
        }
        return try await query.execute().count ?? 0
    }

    // MARK: - Watch time stats

    /// Same filter as the web app: watched items count by when they were
    /// watched, everything else by publish date (fallback created date).
    func fetchStatsItems(startISO: String?) async throws -> [StatsItem] {
        var query = db.from("items")
            .select("id, agent_id, channel_id, channel_name, user_status, created_at, published_at, watched_at")
        if let startISO {
            query = query.or(
                "watched_at.gte.\(startISO),"
                + "and(watched_at.is.null,published_at.gte.\(startISO)),"
                + "and(watched_at.is.null,published_at.is.null,created_at.gte.\(startISO))"
            )
        }
        return try await query.order("created_at", ascending: false).execute().value
    }

    func fetchDurations(itemIds: [String]) async throws -> [String: Int] {
        var map: [String: Int] = [:]
        for chunk in stride(from: 0, to: itemIds.count, by: 200).map({ Array(itemIds[$0..<min($0 + 200, itemIds.count)]) }) {
            let rows: [StatsDuration] = try await db.from("item_analysis")
                .select("item_id, duration_seconds").in("item_id", values: chunk).execute().value
            for row in rows { map[row.itemId] = row.durationSeconds ?? 0 }
        }
        return map
    }

    // MARK: - Mutations

    /// Sets the status on this item and on every other copy of the same video or
    /// post (it can be saved under more than one agent), so marking it once takes
    /// it off every feed on every device. RLS keeps this to the user's own agents.
    func updateItemStatus(id: String, status: ItemStatus) async throws {
        try await db.from("items").update(["user_status": status.rawValue])
            .eq("id", value: id).execute()
        if let videoId = try? await videoIds(forItemIds: [id]).first {
            _ = try? await db.from("items").update(["user_status": status.rawValue])
                .eq("video_id", value: videoId).execute()
        }
    }

    /// Replace an analyzed duration with the authoritative value reported by
    /// the YouTube IFrame player. No fabricated value is ever persisted.
    func updateItemDuration(itemId: String, durationSeconds: Int) async throws {
        guard durationSeconds > 0 else { return }
        try await db.from("item_analysis")
            .update(["duration_seconds": durationSeconds])
            .eq("item_id", value: itemId)
            .execute()
    }

    func bulkUpdateItemStatus(ids: [String], status: ItemStatus) async throws {
        guard !ids.isEmpty else { return }
        try await db.from("items").update(["user_status": status.rawValue])
            .in("id", values: ids).execute()
        // Same for every other copy of those videos/posts.
        guard let videoIds = try? await videoIds(forItemIds: ids), !videoIds.isEmpty else { return }
        for chunk in stride(from: 0, to: videoIds.count, by: 200).map({ Array(videoIds[$0..<min($0 + 200, videoIds.count)]) }) {
            _ = try? await db.from("items").update(["user_status": status.rawValue])
                .in("video_id", values: chunk).execute()
        }
    }

    /// Distinct video_ids of the given items, read in chunks to keep URLs short.
    private func videoIds(forItemIds ids: [String]) async throws -> [String] {
        var result: [String] = []
        var seen = Set<String>()
        for chunk in stride(from: 0, to: ids.count, by: 200).map({ Array(ids[$0..<min($0 + 200, ids.count)]) }) {
            let rows: [ItemVideoIdRow] = try await db.from("items").select("video_id")
                .in("id", values: chunk).execute().value
            for row in rows {
                if let videoId = row.videoId, !videoId.isEmpty, seen.insert(videoId).inserted {
                    result.append(videoId)
                }
            }
        }
        return result
    }

    func upsertDefaultEmail(userId: String, email: String) async throws {
        try await db.from("user_settings")
            .upsert(["user_id": userId, "default_email": email], onConflict: "user_id")
            .execute()
    }

    // MARK: - Runs

    func startRun(agentId: String) async throws -> Run {
        let now = ISO8601DateFormatter().string(from: Date())
        return try await db.from("runs")
            .insert(["agent_id": agentId, "status": "running", "started_at": now])
            .select().single().execute().value
    }

    func invokeRunAgent(agentId: String, runId: String) async throws {
        try await client.functions.invoke(
            "run-agent",
            options: FunctionInvokeOptions(body: ["agentId": agentId, "runId": runId])
        )
    }

    func markRunFailed(runId: String, message: String) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try await db.from("runs")
            .update(["status": "failed", "finished_at": now, "error_summary": message])
            .eq("id", value: runId).execute()
    }

    func cancelRun(runId: String) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try await db.from("runs")
            .update(["status": "cancelled", "finished_at": now])
            .eq("id", value: runId).execute()
    }

    /// Deletes in batches of 100. Sending every id in one request (~2,000
    /// of them) made the URL too long and the server returned Bad Request.
    func clearRuns(ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        for start in stride(from: 0, to: ids.count, by: 100) {
            let batch = Array(ids[start..<min(start + 100, ids.count)])
            try await db.from("runs").delete().in("id", values: batch).execute()
        }
    }

    // MARK: - Channels & recipients

    func toggleChannel(id: String, isEnabled: Bool) async throws {
        try await db.from("channels").update(["is_enabled": isEnabled]).eq("id", value: id).execute()
    }

    func deleteChannel(id: String) async throws {
        try await db.from("channels").delete().eq("id", value: id).execute()
    }

    /// Moves a source to another collection, with the posts it already brought
    /// in. If that collection already follows the same account, the two are
    /// merged: this copy is removed and only posts the other doesn't have move
    /// over. Same steps as moveSource in the web and Expo apps.
    func moveSource(_ channel: Channel, toAgentId: String) async throws {
        struct Row: Decodable { let id: String }
        struct VideoRow: Decodable { let videoId: String? }

        var existingQuery = db.from("channels").select("id").eq("agent_id", value: toAgentId)
        if let channelId = channel.channelId, !channelId.isEmpty {
            existingQuery = existingQuery.eq("channel_id", value: channelId)
        } else {
            existingQuery = existingQuery.eq("channel_url", value: channel.channelUrl ?? "")
        }
        let existing: [Row] = try await existingQuery.limit(1).execute().value

        // Posts first, while the source still says where they came from. Best
        // effort: if this fails the source still moves and its old posts stay.
        if let channelId = channel.channelId, !channelId.isEmpty {
            do {
                let there: [VideoRow] = try await db.from("items").select("video_id")
                    .eq("agent_id", value: toAgentId).eq("channel_id", value: channelId)
                    .execute().value
                let already = Array(Set(there.compactMap(\.videoId)))
                var start = 0
                while start < already.count {
                    let chunk = Array(already[start..<min(start + 200, already.count)])
                    try await db.from("items").delete()
                        .eq("agent_id", value: channel.agentId).eq("channel_id", value: channelId)
                        .in("video_id", values: chunk)
                        .execute()
                    start += 200
                }
                try await db.from("items").update(["agent_id": toAgentId])
                    .eq("agent_id", value: channel.agentId).eq("channel_id", value: channelId)
                    .execute()
            } catch {
                // The source still moves below.
            }
        }

        if existing.isEmpty {
            try await db.from("channels").update(["agent_id": toAgentId]).eq("id", value: channel.id).execute()
        } else {
            try await db.from("channels").delete().eq("id", value: channel.id).execute()
        }
    }

    /// Adds a YouTube channel. add-source looks it up so it has its name,
    /// picture and uploads playlist from the start (the People screen shows
    /// them right away), the same as the web and Expo apps.
    func addChannel(agentId: String, url: String, priority: Int) async throws {
        try await addSource(agentId: agentId, platform: .youtube, value: url, priority: priority)
    }

    /// Adds an account through the add-source edge function, which checks it
    /// exists and fills in its name and picture (same flow as the web and Expo
    /// apps).
    /// `privateAccount` keeps a private Instagram account as a private source.
    @discardableResult
    func addSource(agentId: String, platform: SourcePlatform, value: String, priority: Int, privateAccount: Bool = false) async throws -> Channel {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let fallback = "Couldn't add this \(platform.sourceNoun.lowercased())."
        let response: AddSourceResponse
        do {
            response = try await client.functions.invoke(
                "add-source",
                options: FunctionInvokeOptions(
                    body: AddSourcePayload(
                        agentId: agentId,
                        platform: platform.rawValue,
                        value: value,
                        priority: priority,
                        privateAccount: privateAccount ? true : nil
                    )
                ),
                decoder: decoder
            )
        } catch FunctionsError.httpError(_, let data) {
            // The function explains what went wrong (not found, already added...) in {"error": "..."}.
            let message = (try? decoder.decode(AddSourceResponse.self, from: data))?.error
            throw SourceError(message: message ?? fallback)
        }
        guard let channel = response.channel else {
            throw SourceError(message: response.error ?? fallback, code: response.code)
        }
        return channel
    }

    /// The Spotify version of an Apple Music or YouTube Music release, found by
    /// the spotify-link function (Songlink). nil when Spotify doesn't have it or
    /// the lookup failed.
    func spotifyLink(for url: String) async -> SpotifyLink? {
        do {
            let link: SpotifyLink = try await client.functions.invoke(
                "spotify-link",
                options: FunctionInvokeOptions(body: SpotifyLinkPayload(url: url)),
                decoder: JSONDecoder()
            )
            return link.spotifyUrl == nil ? nil : link
        } catch {
            return nil
        }
    }

    func updateChannelPriority(id: String, priority: Int) async throws {
        try await db.from("channels").update(["priority": priority]).eq("id", value: id).execute()
    }

    func addRecipient(agentId: String, email: String) async throws {
        try await db.from("agent_recipients")
            .insert(["agent_id": agentId, "email": email]).execute()
    }

    func deleteRecipient(id: String) async throws {
        try await db.from("agent_recipients").delete().eq("id", value: id).execute()
    }

    // MARK: - Agents

    func createAgent(_ payload: AgentPayload) async throws -> Agent {
        try await db.from("agents").insert(payload).select().single().execute().value
    }

    func updateAgent(id: String, payload: AgentPayload) async throws -> Agent {
        var patch = payload
        patch.userId = nil
        return try await db.from("agents").update(patch)
            .eq("id", value: id).select().single().execute().value
    }

    func deleteAgent(id: String) async throws {
        try await db.from("agents").delete().eq("id", value: id).execute()
    }

    // MARK: - Resume position (video_progress, shared with web and Android)

    /// Signed-in user's id, lowercased like the web and Android apps store it.
    private var currentUserId: String? {
        client.auth.currentUser?.id.uuidString.lowercased()
    }

    /// Where this user last stopped this video on any device, or nil.
    func fetchVideoProgress(videoId: String) async throws -> VideoProgress? {
        guard let userId = currentUserId else { return nil }
        let rows: [VideoProgressRow] = try await db.from("video_progress")
            .select("position_seconds, duration_seconds, updated_at")
            .eq("user_id", value: userId)
            .eq("video_id", value: videoId)
            .limit(1)
            .execute().value
        guard let row = rows.first else { return nil }
        return VideoProgress(
            position: row.positionSeconds,
            duration: row.durationSeconds,
            updatedAt: Format.parseDate(row.updatedAt) ?? .distantPast
        )
    }

    func saveVideoProgress(videoId: String, position: Double, duration: Double, updatedAt: Date) async throws {
        guard let userId = currentUserId else { return }
        let row = VideoProgressUpsert(
            userId: userId,
            videoId: videoId,
            positionSeconds: position,
            durationSeconds: duration,
            updatedAt: VideoProgress.isoString(updatedAt)
        )
        try await db.from("video_progress")
            .upsert(row, onConflict: "user_id,video_id")
            .execute()
    }

    func deleteVideoProgress(videoId: String) async throws {
        guard let userId = currentUserId else { return }
        try await db.from("video_progress").delete()
            .eq("user_id", value: userId)
            .eq("video_id", value: videoId)
            .execute()
    }

    // MARK: - Account

    /// Delete account via edge function; falls back to best-effort client deletes.
    func deleteAccount(userId: String) async throws -> Bool {
        do {
            try await client.functions.invoke("delete-account")
            return true
        } catch {
            let zeroUUID = "00000000-0000-0000-0000-000000000000"
            _ = try? await db.from("user_settings").delete().eq("user_id", value: userId).execute()
            _ = try? await db.from("youtube_sync_log").delete().eq("user_id", value: userId).execute()
            _ = try? await db.from("watch_time_stats").delete().eq("user_id", value: userId).execute()
            _ = try? await db.from("agents").delete().eq("user_id", value: userId).execute()
            _ = try? await db.from("channels").delete().neq("id", value: zeroUUID).execute()
            _ = try? await db.from("runs").delete().neq("id", value: zeroUUID).execute()
            _ = try? await db.from("items").delete().neq("id", value: zeroUUID).execute()
            _ = try? await db.from("agent_recipients").delete().neq("id", value: zeroUUID).execute()
            return false
        }
    }
}

/// Body for the add-source edge function (camelCase, as the function expects).
nonisolated struct AddSourcePayload: Codable, Sendable {
    var agentId: String
    var platform: String
    var value: String
    var priority: Int
    /// Left out of the body when nil.
    var privateAccount: Bool?
}

nonisolated struct AddSourceResponse: Codable, Sendable {
    var channel: Channel?
    var error: String?
    /// "instagram_private" or "instagram_unavailable" when the account can be
    /// added as a private account instead.
    var code: String?
}

/// Body and answer of the spotify-link edge function (camelCase both ways).
nonisolated struct SpotifyLinkPayload: Encodable, Sendable { let url: String }
nonisolated struct SpotifyLink: Decodable, Sendable {
    var spotifyUrl: String?
    var embedUrl: String?
    var kind: String?
}

/// Readable error from add-source, shown to the user as is.
nonisolated struct SourceError: LocalizedError, Sendable {
    let message: String
    var code: String? = nil
    var errorDescription: String? { message }

    /// Add Source can offer "Add as private account" for this error.
    var canAddAsPrivate: Bool {
        ["instagram_private", "instagram_unavailable", "facebook_profile", "tiktok_private", "x_private"].contains(code ?? "")
    }
}

/// A resume position, in seconds. The same rules apply on web, iOS and Android:
/// resume only from a few seconds in, and the last few seconds count as finished.
/// Long videos use 5 s and 10 s; short clips (X, Instagram) get proportional
/// limits (10% / 5% of the length) so a 20-second clip still resumes.
nonisolated struct VideoProgress: Sendable {
    var position: Double
    var duration: Double
    var updatedAt: Date

    static let minResumeSeconds: Double = 5
    static let endThresholdSeconds: Double = 10

    static func minResume(duration: Double) -> Double {
        duration > 0 ? min(minResumeSeconds, duration * 0.1) : minResumeSeconds
    }

    static func isNearEnd(position: Double, duration: Double) -> Bool {
        duration > 0 && position >= duration - min(endThresholdSeconds, duration * 0.05)
    }

    /// The time to seek to, or nil when it's too close to the start or the end.
    static func resumeTime(position: Double, duration: Double) -> Double? {
        guard position >= minResume(duration: duration), !isNearEnd(position: position, duration: duration) else { return nil }
        return position
    }

    static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

/// Row read from video_progress.
nonisolated struct VideoProgressRow: Codable, Sendable {
    var positionSeconds: Double
    var durationSeconds: Double
    var updatedAt: String
}

/// Row written to video_progress (keys become snake_case via the client's encoder).
nonisolated struct VideoProgressUpsert: Codable, Sendable {
    var userId: String
    var videoId: String
    var positionSeconds: Double
    var durationSeconds: Double
    var updatedAt: String
}

/// items.video_id, for giving every copy of a video/post the same status.
nonisolated struct ItemVideoIdRow: Codable, Sendable {
    var videoId: String?
}
