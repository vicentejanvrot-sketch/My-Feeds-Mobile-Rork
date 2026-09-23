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
                db: .init(encoder: encoder, decoder: decoder)
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

    func fetchFeedItems(limit: Int = 500) async throws -> [FeedItem] {
        do {
            return try await db.from("items").select("*, item_analysis(*)")
                .order("published_at", ascending: false, nullsFirst: false)
                .limit(limit).execute().value
        } catch {
            // A single malformed/legacy analysis row must not prevent the
            // native app from showing its videos. Retry with the base item
            // fields; FeedItem's optional analysis then falls back gracefully.
            var items: [FeedItem] = try await db.from("items").select()
                .order("published_at", ascending: false, nullsFirst: false)
                .limit(limit).execute().value
            let durations = (try? await fetchDurations(itemIds: items.map(\.id))) ?? [:]
            for index in items.indices {
                items[index].resolvedDurationSeconds = durations[items[index].id]
            }
            return items
        }
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
                    let counts = try await AgentItemCounts(
                        total: total, watched: watched, unwatched: unwatched,
                        watchLater: later, liked: liked
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

    func updateItemStatus(id: String, status: ItemStatus) async throws {
        try await db.from("items").update(["user_status": status.rawValue])
            .eq("id", value: id).execute()
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

    func clearRuns(ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        try await db.from("runs").delete().in("id", values: ids).execute()
    }

    // MARK: - Channels & recipients

    func toggleChannel(id: String, isEnabled: Bool) async throws {
        try await db.from("channels").update(["is_enabled": isEnabled]).eq("id", value: id).execute()
    }

    func deleteChannel(id: String) async throws {
        try await db.from("channels").delete().eq("id", value: id).execute()
    }

    func addChannel(agentId: String, url: String, priority: Int) async throws {
        try await db.from("channels")
            .insert(AddChannelPayload(agentId: agentId, channelUrl: url, priority: priority))
            .execute()
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

nonisolated struct AddChannelPayload: Codable, Sendable {
    var agentId: String
    var channelUrl: String
    var priority: Int
}
