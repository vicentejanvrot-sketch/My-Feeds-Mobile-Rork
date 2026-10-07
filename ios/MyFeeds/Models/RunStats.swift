import Foundation

/// Dashboard "Recent Runs" and "Success Rate", from the dashboard_run_stats()
/// database function. The web app and Android call the same function, so all
/// three apps always show the same numbers.
///
/// Last 7 days. Success Rate = runs that finished with no errors / runs that
/// finished (success, partial or failed); running and cancelled runs are left out.
struct RunStats: Decodable, Equatable {
    static let days = 7

    var runs: Int
    var finished: Int
    var succeeded: Int
    var partial: Int
    var failed: Int
    /// Whole percent, nil when no run has finished in the period.
    var successRate: Int?

    static let empty = RunStats(runs: 0, finished: 0, succeeded: 0, partial: 0, failed: 0, successRate: nil)
}
