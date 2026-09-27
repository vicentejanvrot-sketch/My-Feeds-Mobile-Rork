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

    /// Checks one followed source for accounts on other platforms through the
    /// find-also-on edge function, which saves what it finds in identity_links
    /// and records the check in identity_scans.
    func findAlsoOn(channelId: String) async throws {
        do {
            try await client.functions.invoke(
                "find-also-on",
                options: FunctionInvokeOptions(body: ["channelId": channelId])
            )
        } catch FunctionsError.httpError(_, let data) {
            // The function explains what went wrong in {"error": "..."}.
            let message = (try? JSONDecoder().decode(EdgeFunctionErrorBody.self, from: data))?.error
            throw SourceError(message: message ?? "Couldn't check this source.")
        }
    }

    /// "Same person" confirms a possible match; "Not them" rejects it. Either way
    /// the function never overwrites the user's decision on a later check.
    func decideIdentityLink(id: String, same: Bool) async throws {
        let decision = same
            ? IdentityDecision(status: "confirmed", method: "user", evidence: "You confirmed this match.", decidedByUser: true)
            : IdentityDecision(status: "rejected", method: nil, evidence: nil, decidedByUser: true)
        try await client.schema("public").from("identity_links")
            .update(decision)
            .eq("id", value: id)
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
