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
    /// Kinds of posts left out, per platform (ContentTypes). Keys come back
    /// camelCased by the decoder; read them through ContentTypes.normalized.
    var contentTypes: [String: Bool]?
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
    var contentTypes: [String: Bool]
    var minDurationMinutes: Int
    var freshnessWeight: Double
    var priorityWeight: Double
    var durationWeight: Double
    var keywordWeight: Double
    var keywords: [String]?
    var userId: String?
}

extension Agent {
    /// schedule_frequency ("daily", "weekly", "hourly", none) as shown to the user.
    static func frequencyLabel(_ value: String?) -> String {
        switch value?.lowercased() {
        case "daily": return String(localized: "Daily", bundle: .appStrings)
        case "weekly": return String(localized: "Weekly", bundle: .appStrings)
        case "hourly": return String(localized: "Hourly", bundle: .appStrings)
        case nil, "", "manual": return String(localized: "Manual", bundle: .appStrings)
        default: return value ?? ""
        }
    }
}
