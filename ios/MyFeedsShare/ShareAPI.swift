import Foundation
import Supabase

/// What the add-source edge function says about a shared link (preview: true).
/// Same shape as src/lib/shareAdd.ts (web) and expo/lib/shareAdd.ts.
nonisolated struct SharePreview: Decodable, Sendable {
    nonisolated struct Account: Decodable, Sendable {
        let name: String
        let handle: String?
        let url: String
        let thumbnail: String?
        let channelId: String?
        let isPrivate: Bool?
    }
    nonisolated struct Placement: Decodable, Sendable {
        let agentId: String
        let agentName: String
    }
    nonisolated struct Suggestion: Decodable, Sendable {
        let agentId: String
        let agentName: String
        let reason: String?
    }
    nonisolated struct OtherAccount: Decodable, Sendable {
        let platform: String
        let url: String
        let label: String
        let matchKey: String
    }
    nonisolated struct Collection: Decodable, Sendable, Identifiable {
        let id: String
        let name: String
    }

    let platform: String
    let platformLabel: String
    let kind: String
    let value: String
    let account: Account
    let inCollections: [Placement]
    let suggestion: Suggestion?
    let alsoOn: [OtherAccount]
    var collections: [Collection]
}

nonisolated struct NewCollection: Encodable, Sendable {
    let name: String
    let user_id: String
}

nonisolated struct AddedChannel: Decodable, Sendable {
    let id: String
    let agent_id: String
}

nonisolated enum ShareAPIError: LocalizedError {
    case notSignedIn
    case message(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Open My Feeds and sign in first, then share again."
        case .message(let text): return text
        }
    }
}

/// The share extension's calls. It signs in with the app's own session, kept
/// in the shared keychain (SharedAuthStorage), and refreshes it there when needed.
nonisolated final class ShareAPI: @unchecked Sendable {
    static let unsortedId = "__unsorted__"

    private static let supabaseURL = "https://wavkxbkirkyjwtnszmya.supabase.co"
    private static let anonKey =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indhdmt4Ymtpcmt5and0bnN6bXlhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkyMjQxNjcsImV4cCI6MjA4NDgwMDE2N30.kBXxvf6bPTx7DuFD_PRMTmcOzKCv9rJmVonl_rTAPiE"

    private let client = SupabaseClient(
        supabaseURL: URL(string: ShareAPI.supabaseURL)!,
        supabaseKey: ShareAPI.anonKey,
        options: SupabaseClientOptions(auth: .init(storage: SharedAuthStorage(), autoRefreshToken: false))
    )

    private func accessToken() async throws -> String {
        do {
            return try await client.auth.session.accessToken
        } catch {
            throw ShareAPIError.notSignedIn
        }
    }

    private func callAddSource(_ body: [String: Any]) async throws -> [String: Any] {
        let token = try await accessToken()
        var request = URLRequest(url: URL(string: ShareAPI.supabaseURL + "/functions/v1/add-source")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue(ShareAPI.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if (response as? HTTPURLResponse)?.statusCode == 401 { throw ShareAPIError.notSignedIn }
        return json
    }

    func preview(_ shared: String) async throws -> SharePreview {
        let json = try await callAddSource(["preview": true, "value": shared])
        if let raw = json["preview"] {
            let data = try JSONSerialization.data(withJSONObject: raw)
            return try JSONDecoder().decode(SharePreview.self, from: data)
        }
        throw ShareAPIError.message(json["error"] as? String ?? "Couldn't read that link.")
    }

    /// Adds the account (and, when asked, their other accounts) to every chosen
    /// collection. Returns the new source rows so the add can be undone.
    func add(_ preview: SharePreview, agentIds: [String], priority: Int, includeAlsoOn: Bool) async throws -> [AddedChannel] {
        var targets: [(String, String)] = [(preview.platform, preview.value)]
        if includeAlsoOn { targets += preview.alsoOn.map { ($0.platform, $0.url) } }
        var added: [AddedChannel] = []
        for (index, target) in targets.enumerated() {
            let json = try await callAddSource([
                "agentIds": agentIds,
                "platform": target.0,
                "value": target.1,
                "priority": priority,
            ])
            var rows: [AddedChannel] = []
            if let raw = json["channels"], let data = try? JSONSerialization.data(withJSONObject: raw) {
                rows = (try? JSONDecoder().decode([AddedChannel].self, from: data)) ?? []
            }
            // The main account has to go in; their other accounts are best effort.
            if index == 0 && rows.isEmpty {
                throw ShareAPIError.message(json["error"] as? String ?? "Couldn't add that account.")
            }
            added += rows
        }
        return added
    }

    /// A new, empty collection made from the picker while adding an account.
    /// Reuses one with the same name instead of making a duplicate.
    func createCollection(name: String, existing: [SharePreview.Collection]) async throws -> SharePreview.Collection {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw ShareAPIError.message("Give the collection a name.") }
        if let same = existing.first(where: { $0.name.trimmingCharacters(in: .whitespaces).lowercased() == clean.lowercased() }) {
            return same
        }
        let userId: String
        do {
            userId = try await client.auth.session.user.id.uuidString.lowercased()
        } catch {
            throw ShareAPIError.notSignedIn
        }
        let made: SharePreview.Collection = try await client.from("agents")
            .insert(NewCollection(name: clean, user_id: userId))
            .select("id, name")
            .single()
            .execute()
            .value
        return made
    }

    func undo(_ channels: [AddedChannel]) async throws {
        guard !channels.isEmpty else { return }
        _ = try await accessToken()
        try await client.from("channels").delete().in("id", values: channels.map(\.id)).execute()
    }
}
