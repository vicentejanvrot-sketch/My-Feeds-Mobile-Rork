import Foundation

/// Row in the shared `runs` table.
nonisolated struct Run: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var agentId: String
    var startedAt: String?
    var finishedAt: String?
    var status: String
    var videosFoundCount: Int?
    var videosNewCount: Int?
    var videosEnrichedCount: Int?
    var errorSummary: String?
    var channelsTotal: Int?
    var channelsScanned: Int?
    var currentChannelName: String?

    var runStatus: RunStatus { RunStatus(rawValue: status) ?? .cancelled }
}

/// What the run-agent edge function replies once the scan is done.
/// `skipped` is set when the collection has no sources turned on; run-agent
/// then logs its own failed run and never touches the row the app made.
nonisolated struct RunAgentReply: Decodable, Sendable {
    var success: Bool?
    var skipped: Bool?
    var reason: String?
    var status: String?
    var videosNew: Int?
}
