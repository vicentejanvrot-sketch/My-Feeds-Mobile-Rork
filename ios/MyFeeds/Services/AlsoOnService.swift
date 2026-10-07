import Foundation
import Supabase

/// Data for the Following screen: identity links and scans, checking a source
/// for other platforms, Same person / Not them, and following a found account.
/// Same behaviour as src/hooks/useAlsoOn.ts (web) and expo/lib/useAlsoOn.ts.
extension SupabaseService {
    func fetchIdentityLinks() async throws -> [IdentityLink] {
        try await client.schema("public").from("identity_links").select().execute().value
    }

    func fetchIdentityScans() async throws -> [IdentityScan] {
        try await client.schema("public").from("identity_scans").select().execute().value
    }

    /// Checks one person for accounts on other platforms through the
    /// find-also-on edge function, which saves what it finds in identity_links
    /// and records the check in identity_scans. channelIds are every source the
    /// person is followed through, most important first: they're searched
    /// together, so their name, Wikidata and Apple are looked up once.
    func findAlsoOn(channelIds: [String]) async throws {
        do {
            try await client.functions.invoke(
                "find-also-on",
                options: FunctionInvokeOptions(body: ["channelIds": channelIds])
            )
        } catch FunctionsError.httpError(_, let data) {
            // The function explains what went wrong in {"error": "..."}.
            let message = (try? JSONDecoder().decode(EdgeFunctionErrorBody.self, from: data))?.error
            throw SourceError(message: message ?? String(localized: "Couldn't check this source."))
        }
    }

    /// "Same person" confirms a possible match; "Not them" rejects it. Either way
    /// the function never overwrites the user's decision on a later check.
    /// channelIds are all the sources of this person (the same account followed
    /// in several agents): the answer is saved on every copy of the match.
    func decideIdentityLink(_ link: IdentityLink, channelIds: [String], same: Bool) async throws {
        let decision = same
            ? IdentityDecision(status: "confirmed", method: "user", evidence: "You confirmed this match.", decidedByUser: true)
            : IdentityDecision(status: "rejected", method: nil, evidence: nil, decidedByUser: true)
        var ids = channelIds
        if !ids.contains(link.channelId) { ids.append(link.channelId) }
        try await client.schema("public").from("identity_links")
            .update(decision)
            .eq("match_key", value: link.matchKey)
            .in("channel_id", values: ids)
            .execute()
    }

    /// Combines two cards into one person, for when the same person was added
    /// twice under names the search couldn't tie together. Saved as a match the
    /// user confirmed, so it also holds after a new search. Same as the web app.
    func combinePeople(_ person: AlsoOnPerson, with other: AlsoOnPerson) async throws {
        guard let userId = client.auth.currentUser?.id.uuidString.lowercased() else {
            throw SourceError(message: String(localized: "You're signed out. Sign in again and retry."))
        }
        guard let row = AlsoOn.mergeRow(person, other, userId: userId) else {
            throw SourceError(message: String(localized: "These two can't be combined yet."))
        }
        try await client.schema("public").from("identity_links")
            .upsert(row, onConflict: "channel_id,match_key")
            .execute()
    }

    /// Undoes "Combine": every card combined into this one becomes its own card again.
    func separatePerson(_ person: AlsoOnPerson) async throws {
        try await client.schema("public").from("identity_links")
            .delete()
            .in("channel_id", values: person.sources.map { $0.id })
            .like("match_key", pattern: AlsoOn.mergeKeyPrefix + "%")
            .execute()
    }

    /// Adds a found account to an agent the same way the agent screen's Add
    /// Source does: YouTube as a channel row, everything else through add-source.
    func followAccount(platform: SourcePlatform, url: String, agentId: String) async throws {
        if platform == .youtube {
            try await addChannel(agentId: agentId, url: url, priority: 3)
        } else {
            try await addSource(agentId: agentId, platform: platform, value: url, priority: 3)
        }
    }
}

/// Update for identity_links (encoded via convertToSnakeCase; nil fields are left out).
nonisolated struct IdentityDecision: Encodable, Sendable {
    var status: String
    var method: String?
    var evidence: String?
    var decidedByUser: Bool
}

nonisolated struct EdgeFunctionErrorBody: Decodable, Sendable {
    var error: String?
}
