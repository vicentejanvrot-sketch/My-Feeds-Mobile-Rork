import Foundation

/// Date parsing + formatting helpers matching the companion apps exactly.
nonisolated enum Format {
    nonisolated(unsafe) private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Parse a Supabase timestamp string ("2026-06-09T18:21:33.123+00:00" or without fraction/zone).
    static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        if let d = isoFractional.date(from: value) { return d }
        if let d = iso.date(from: value) { return d }
        // Timestamps without timezone (assume UTC)
        let patched = value.contains("+") || value.hasSuffix("Z") ? value : value + "Z"
        if let d = isoFractional.date(from: patched) { return d }
        return iso.date(from: patched)
    }

    /// Relative time like "3h ago", "2d ago".
    static func timeAgo(_ isoString: String?) -> String {
        guard let date = parseDate(isoString) else { return "—" }
        let sec = Int((Date().timeIntervalSince(date)).rounded())
        if sec < 60 { return "just now" }
        let min = Int((Double(sec) / 60).rounded())
        if min < 60 { return "\(min)m ago" }
        let hr = Int((Double(min) / 60).rounded())
        if hr < 24 { return "\(hr)h ago" }
        let day = Int((Double(hr) / 24).rounded())
        if day < 30 { return "\(day)d ago" }
        let mo = Int((Double(day) / 30).rounded())
        if mo < 12 { return "\(mo)mo ago" }
        return "\(Int((Double(mo) / 12).rounded()))y ago"
    }

    /// Human relative time like "about 3 hours ago".
    static func relativeTime(_ isoString: String?) -> String {
        guard let date = parseDate(isoString) else { return "—" }
        let sec = Int((Date().timeIntervalSince(date)).rounded())
        if sec < 10 { return "just now" }
        if sec < 60 { return "less than a minute ago" }
        let min = Int((Double(sec) / 60).rounded())
        if min == 1 { return "about 1 minute ago" }
        if min < 60 { return "about \(min) minutes ago" }
        let hr = Int((Double(min) / 60).rounded())
        if hr == 1 { return "about 1 hour ago" }
        if hr < 24 { return "about \(hr) hours ago" }
        let day = Int((Double(hr) / 24).rounded())
        if day == 1 { return "about 1 day ago" }
        if day < 30 { return "about \(day) days ago" }
        let mo = Int((Double(day) / 30).rounded())
        if mo == 1 { return "about 1 month ago" }
        if mo < 12 { return "about \(mo) months ago" }
        let yr = Int((Double(mo) / 12).rounded())
        return yr == 1 ? "about 1 year ago" : "about \(yr) years ago"
    }

    /// Compact count like 1.2K, 3.4M.
    static func compactNumber(_ n: Int?) -> String {
        guard let n else { return "—" }
        if n < 1000 { return String(n) }
        if n < 1_000_000 {
            let v = Double(n) / 1000
            return n < 10_000 ? String(format: "%.1fK", v) : String(format: "%.0fK", v)
        }
        let v = Double(n) / 1_000_000
        return n < 10_000_000 ? String(format: "%.1fM", v) : String(format: "%.0fM", v)
    }

    /// Seconds → "12:34" or "1:02:03".
    static func duration(_ seconds: Int?) -> String {
        guard let seconds, seconds > 0 else { return "—" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    /// Seconds → "Xh Ym" / "Ym" for watch-time stats.
    static func watchDuration(_ seconds: Int) -> String {
        if seconds <= 0 { return "0m" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        // Same format as the web app: "3h", "3h 5m", "5m".
        if h > 0 { return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
        return "\(m)m"
    }

    /// Player time "m:ss" / "h:mm:ss".
    static func playerTime(_ seconds: Double) -> String {
        duration(Int(seconds.rounded())) == "—" ? "0:00" : duration(Int(seconds.rounded()))
    }

    /// Full run timestamp like "Jun 9, 2026 at 6:21 PM".
    static func runTimestamp(_ isoString: String?) -> String {
        guard let date = parseDate(isoString) else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return f.string(from: date)
    }

    /// Run duration between two timestamps: "42s" / "3m 12s" / "In progress".
    static func runDuration(started: String?, finished: String?) -> String {
        guard let start = parseDate(started) else { return "—" }
        guard let end = parseDate(finished) else { return "In progress" }
        let sec = Int(end.timeIntervalSince(start))
        if sec < 0 { return "—" }
        if sec < 60 { return "\(sec)s" }
        let m = sec / 60
        let rem = sec % 60
        return rem == 0 ? "\(m)m" : "\(m)m \(rem)s"
    }
}
