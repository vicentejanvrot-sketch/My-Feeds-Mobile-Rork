import Foundation

/// Row in the shared `agents` table (decoded via convertFromSnakeCase).
nonisolated struct Agent: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var userId: String?
    var name: String
    var description: String?
    var scheduleFrequency: String?
    var runTimeLocal: String?
    var timezone: String?
    var lookbackHours: Int?
    var includeShorts: Bool?
    var includeLive: Bool?
    var minDurationMinutes: Int?
    var aiProvider: String?
    var freshnessWeight: Double?
    var priorityWeight: Double?
    var durationWeight: Double?
    var keywordWeight: Double?
    var keywords: [String]?
    var createdAt: String?
    var updatedAt: String?
}

/// Just the description, sent as null when cleared (a plain optional would be
/// left out of the JSON and not clear it).
nonisolated struct AgentDescriptionPatch: Encodable, Sendable {
    var description: String?

    enum CodingKeys: String, CodingKey { case description }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(description, forKey: .description)
    }
}

/// Payload for creating/updating agents. Encoded via convertToSnakeCase.
nonisolated struct AgentPayload: Codable, Sendable {
    var name: String
    var description: String?
    var scheduleFrequency: String
    var runTimeLocal: String
    var timezone: String
    var lookbackHours: Int
    var aiProvider: String
    var includeShorts: Bool
    var includeLive: Bool
    var minDurationMinutes: Int
    var freshnessWeight: Double
    var priorityWeight: Double
    var durationWeight: Double
    var keywordWeight: Double
    var keywords: [String]?
    var userId: String?
}
