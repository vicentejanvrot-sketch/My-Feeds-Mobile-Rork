import Foundation

// "Also on": groups the sources a user follows into people and companies,
// and lists where else each one has an account. Rows come from the
// identity_links / identity_scans tables filled by the find-also-on edge
// function (web repo). Same rules as src/lib/alsoOn.ts on the web and
// expo/lib/alsoOn.ts, so every app groups people the same way.

/// Row in identity_links: another account found for a followed source.
nonisolated struct IdentityLink: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var userId: String?
    var channelId: String
    var platform: String?
    /// "x:name", "instagram:name", "youtube:UC...", "youtube:@handle",
    /// "linkedin:in:slug", "linkedin:company:slug", "reddit:u:name", "github:login"
    var matchKey: String
    var handle: String?
    var url: String
    var displayName: String?
    var thumbnail: String?
    /// "confirmed" | "possible" | "rejected"
    var status: String
    var method: String?
    var evidence: String?
    var decidedByUser: Bool?
    var createdAt: String?
    var updatedAt: String?

    var sourcePlatform: SourcePlatform { SourcePlatform(raw: platform) }
    var isConfirmed: Bool { status == "confirmed" }
    var isRejected: Bool { status == "rejected" }
}

/// Row in identity_scans: when a followed source was last checked.
nonisolated struct IdentityScan: Codable, Hashable, Sendable {
    var channelId: String
    var userId: String?
    var scannedAt: String
    var aisaCalls: Int?
    var foundCount: Int?
    var error: String?
}

/// An account the user already follows, as shown on a person.
nonisolated struct AlsoOnFollowedAccount: Identifiable, Hashable, Sendable {
    let key: String
    let platform: SourcePlatform
    let label: String
    let url: String
    let channel: Channel

    var id: String { channel.id }
}

/// An account found somewhere the user doesn't follow this person yet.
nonisolated struct AlsoOnFoundAccount: Identifiable, Hashable, Sendable {
    let isConfirmed: Bool
    let key: String
    let platform: SourcePlatform
    let label: String
    let url: String
    let link: IdentityLink

    var id: String { key }
}

/// One person or company, made of every source that is the same account.
nonisolated struct AlsoOnPerson: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let thumbnail: String?
    let sources: [Channel]
    let agentIds: [String]
    let following: [AlsoOnFollowedAccount]
    let also: [AlsoOnFoundAccount]
    let possible: [AlsoOnFoundAccount]
    let lastScannedAt: String?
    let scanErrors: [String]
    /// Cards the user combined by hand ("Combine"), kept so they can be
    /// separated again.
    let merges: [IdentityLink]

    var platformCount: Int { following.count + also.count }
}

/// Row written to identity_links to combine two cards (keys become snake_case
/// via the client's encoder).
nonisolated struct IdentityMergeRow: Encodable, Sendable {
    var userId: String
    var channelId: String
    var platform: String
    var matchKey: String
    var handle: String?
    var url: String
    var displayName: String?
    var thumbnail: String?
    var status: String
    var method: String
    var evidence: String
    var decidedByUser: Bool
}

nonisolated enum AlsoOn {
    /// AIsa lookups one person's search may use (more when they're followed in
    /// several places, up to a cap, matching find-also-on), and AIsa's listed
    /// median price per call.
    static let maxLookupsPerPerson = 20
    static func maxLookups(sources: Int) -> Int {
        min(maxLookupsPerPerson + 3 * max(0, sources - 1), 30)
    }
    static let aisaPricePerCall = 0.012
    /// Sources checked longer ago than this are offered for a new check.
    static let rescanAfterDays = 30

    /// Subreddits and keyword searches aren't people or companies. Reddit users
    /// are, and are saved as "account" sources.
    static func isPersonSource(_ ch: Channel) -> Bool {
        if ch.sourcePlatform == .reddit { return ch.sourceType == "account" }
        return ch.sourceType != "subreddit" && ch.sourceType != "keyword"
    }

    static func isYouTubeChannelId(_ value: String) -> Bool {
        guard value.hasPrefix("UC"), value.count >= 12 else { return false }
        return value.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }
    }

    private static func stripAt(_ value: String) -> String {
        value.hasPrefix("@") ? String(value.dropFirst()) : value
    }

    /// "u/name", "/user/name" -> "name"
    private static func redditName(_ value: String) -> String {
        for prefix in ["/user/", "user/", "/u/", "u/"] where value.lowercased().hasPrefix(prefix) {
            return String(value.dropFirst(prefix.count))
        }
        return value
    }

    /// The account key a profile URL points at (same format as match_key).
    static func accountKey(fromURL raw: String?) -> String? {
        guard let raw,
              let comps = URLComponents(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              let rawHost = comps.host else { return nil }
        var host = rawHost.lowercased()
        for prefix in ["www.", "m.", "mobile.", "old.", "new."] where host.hasPrefix(prefix) {
            host = String(host.dropFirst(prefix.count))
            break
        }
        let parts = comps.path.split(separator: "/").map { String($0) }
        let first = parts.first ?? ""
        let second: String? = parts.count > 1 ? parts[1] : nil

        if host == "x.com" || host == "twitter.com" {
            return first.isEmpty ? nil : "x:" + stripAt(first).lowercased()
        }
        if host == "instagram.com" {
            return first.isEmpty ? nil : "instagram:" + first.lowercased()
        }
        if host == "facebook.com" || host == "fb.com" {
            // Same key as find-also-on: facebook:<page name>.
            let isPage = first.range(of: "^[A-Za-z0-9.\\-]{2,80}$", options: .regularExpression) != nil
                && !first.lowercased().hasSuffix(".php")
            return isPage ? "facebook:" + first.lowercased() : nil
        }
        if host == "youtube.com" {
            if first.hasPrefix("@") { return "youtube:@" + String(first.dropFirst()).lowercased() }
            if first == "channel", let second { return "youtube:" + second }
            if first == "c" || first == "user", let second { return "youtube:c:" + second.lowercased() }
            return nil
        }
        if host == "open.spotify.com" {
            // Same key as find-also-on: spotify:artist:<id> / spotify:show:<id> (ids are case-sensitive).
            let rest = first.hasPrefix("intl-") ? Array(parts.dropFirst()) : parts
            guard rest.count > 1, rest[0] == "artist" || rest[0] == "show" else { return nil }
            return "spotify:" + rest[0] + ":" + rest[1]
        }
        if host == "music.youtube.com" {
            guard let range = comps.path.range(of: #"/channel/UC[\w-]{20,}"#, options: .regularExpression) else { return nil }
            return "youtube_music:" + comps.path[range].replacingOccurrences(of: "/channel/", with: "")
        }
        if host == "books.apple.com" || (host == "itunes.apple.com" && comps.path.contains("/author/")) {
            guard let range = comps.path.range(of: #"/author/(?:[^/]+/)?(?:id)?\d+"#, options: .regularExpression) else { return nil }
            let digits = comps.path[range].split(separator: "/").last.map { String($0).replacingOccurrences(of: "id", with: "") } ?? ""
            return digits.isEmpty ? nil : "apple_books:" + digits
        }
        if host == "music.apple.com" || host == "itunes.apple.com" || host == "podcasts.apple.com" {
            let path = comps.path
            if host != "podcasts.apple.com",
               let range = path.range(of: #"/artist/(?:[^/]+/)?(?:id)?\d+"#, options: .regularExpression) {
                let digits = path[range].split(separator: "/").last.map { String($0).replacingOccurrences(of: "id", with: "") } ?? ""
                return digits.isEmpty ? nil : "apple_music:" + digits
            }
            if let range = path.range(of: #"/podcast/(?:[^/]+/)?id\d+"#, options: .regularExpression) {
                let digits = path[range].split(separator: "/").last.map { String($0).replacingOccurrences(of: "id", with: "") } ?? ""
                return digits.isEmpty ? nil : "apple_podcasts:" + digits
            }
            return nil
        }
        if host == "reddit.com" {
            let kind = first.lowercased()
            guard kind == "user" || kind == "u", let second else { return nil }
            return "reddit:u:" + second.lowercased()
        }
        if host == "github.com" {
            // A repo link (github.com/owner/repo) belongs to its owner.
            guard first.range(of: "^[A-Za-z0-9][A-Za-z0-9-]{0,38}$", options: .regularExpression) != nil else { return nil }
            return "github:" + first.lowercased()
        }
        if host == "linkedin.com" || host.hasSuffix(".linkedin.com") {
            guard let second else { return nil }
            let kind = first.lowercased()
            if kind == "in" { return "linkedin:in:" + second.lowercased() }
            if kind == "company" || kind == "school" || kind == "showcase" {
                return "linkedin:company:" + second.lowercased()
            }
        }
        return nil
    }

    /// Every key a followed source is known by (same format as match_key).
    static func channelKeys(_ ch: Channel) -> [String] {
        let platform = ch.sourcePlatform
        var keys: [String] = []
        func add(_ key: String) {
            if !keys.contains(key) { keys.append(key) }
        }
        if let fromURL = accountKey(fromURL: ch.channelUrl) { add(fromURL) }
        if let channelId = ch.channelId, !channelId.isEmpty {
            if platform == .youtube && isYouTubeChannelId(channelId) { add("youtube:" + channelId) }
            if platform != .youtube { add(channelId.lowercased()) }
        }
        if let handle = ch.handle, !handle.isEmpty, platform == .x || platform == .instagram {
            add(platform.rawValue + ":" + stripAt(handle).lowercased())
        }
        return keys
    }

    /// A found account's keys: its match_key plus the key its URL gives (a YouTube
    /// channel found as youtube:UC... is followed by its @handle URL).
    static func linkKeys(_ link: IdentityLink) -> [String] {
        if let fromURL = accountKey(fromURL: link.url), fromURL != link.matchKey {
            return [link.matchKey, fromURL]
        }
        return [link.matchKey]
    }

    /// "Lena Ortiz (@lenabuilds)" -> "Lena Ortiz"
    static func cleanName(_ name: String?, fallback: String) -> String {
        var value = name ?? ""
        if let range = value.range(of: "\\s*\\(@[^)]*\\)\\s*$", options: .regularExpression) {
            value.removeSubrange(range)
        }
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? fallback : value
    }

    static func accountLabel(platform: SourcePlatform, handle: String?, url: String) -> String {
        if platform == .appleMusic { return String(localized: "Artist page") }
        if platform == .applePodcasts { return String(localized: "Show") }
        if platform == .appleBooks { return String(localized: "Author") }
        if platform == .youtubeMusic { return String(localized: "Artist") }
        if platform == .spotify { return url.contains("/show/") ? String(localized: "Show") : String(localized: "Artist") }
        guard let handle, !handle.isEmpty, platform != .facebook else {
            var value = url
            for prefix in ["https://www.", "http://www.", "https://", "http://"] where value.hasPrefix(prefix) {
                value = String(value.dropFirst(prefix.count))
                break
            }
            if value.hasSuffix("/") { value.removeLast() }
            return value
        }
        switch platform {
        case .x, .instagram, .tiktok: return "@" + handle
        case .youtube: return isYouTubeChannelId(handle) ? String(localized: "Channel") : "@" + handle
        case .reddit: return "u/" + redditName(handle)
        default: return handle
        }
    }

    static func sourceLabel(_ ch: Channel) -> String {
        let platform = ch.sourcePlatform
        if let handle = ch.handle, !handle.isEmpty, platform == .x || platform == .instagram || platform == .tiktok {
            return "@" + stripAt(handle)
        }
        if let url = ch.channelUrl, let range = url.range(of: "youtube\\.com/@[^/?#]+", options: .regularExpression) {
            let match = url[range]
            if let at = match.firstIndex(of: "@") { return String(match[at...]) }
        }
        if platform == .linkedin || platform == .github, let handle = ch.handle, !handle.isEmpty { return handle }
        if platform == .reddit, let handle = ch.handle, !handle.isEmpty { return "u/" + redditName(handle) }
        return cleanName(ch.channelName, fallback: ch.channelUrl ?? String(localized: "Source"))
    }

    /// Where to follow this account on the platform itself. X and YouTube open
    /// their own follow / subscribe prompt; LinkedIn and Instagram open the
    /// profile, since neither lets other apps follow accounts for the user.
    static func platformFollowURL(platform: SourcePlatform, url: String) -> URL? {
        if platform == .x, let key = accountKey(fromURL: url), key.hasPrefix("x:") {
            var comps = URLComponents(string: "https://x.com/intent/follow")
            comps?.queryItems = [URLQueryItem(name: "screen_name", value: String(key.dropFirst(2)))]
            return comps?.url
        }
        if platform == .youtube, var comps = URLComponents(string: url) {
            var items = (comps.queryItems ?? []).filter { $0.name != "sub_confirmation" }
            items.append(URLQueryItem(name: "sub_confirmation", value: "1"))
            comps.queryItems = items
            return comps.url ?? URL(string: url)
        }
        return URL(string: url)
    }

    static func initials(_ name: String) -> String {
        let trimmed = name.hasPrefix("r/") ? String(name.dropFirst(2)) : name
        let parts = trimmed.split(whereSeparator: { $0.isWhitespace })
        if parts.count > 1, let a = parts[0].first, let b = parts[1].first {
            return (String(a) + String(b)).uppercased()
        }
        return String((parts.first.map { String($0) } ?? "?").prefix(2)).uppercased()
    }

    /// A card combined by hand is saved as a confirmed match from one card's
    /// source to another followed source, keyed by that source's id:
    /// source:<channel id>. It only ties the two together; it's never shown as
    /// an account of its own. Same as the web app.
    static let mergeKeyPrefix = "source:"
    static func isMergeLink(_ link: IdentityLink) -> Bool { link.matchKey.hasPrefix(mergeKeyPrefix) }

    /// Platforms a match can be saved under (identity_links.platform). A TikTok
    /// source can't be the target, so the link goes the other way round.
    private static let linkable: Set<SourcePlatform> = [
        .youtube, .x, .instagram, .facebook, .linkedin, .reddit, .github,
        .appleMusic, .applePodcasts, .appleBooks, .youtubeMusic, .spotify,
    ]

    /// The row that combines two cards: saved on one of `a`'s sources, pointing
    /// at one of `b`'s (or the other way round when only that works). Nil when
    /// neither card has a source that can be linked to.
    static func mergeRow(_ a: AlsoOnPerson, _ b: AlsoOnPerson, userId: String) -> IdentityMergeRow? {
        func pick(_ from: AlsoOnPerson, _ to: AlsoOnPerson) -> (owner: Channel, target: Channel)? {
            guard let owner = from.sources.first,
                  let target = to.sources.first(where: { linkable.contains($0.sourcePlatform) }) else { return nil }
            return (owner, target)
        }
        guard let pair = pick(a, b) ?? pick(b, a) else { return nil }
        return IdentityMergeRow(
            userId: userId,
            channelId: pair.owner.id,
            platform: pair.target.sourcePlatform.rawValue,
            matchKey: mergeKeyPrefix + pair.target.id,
            handle: pair.target.handle,
            url: pair.target.channelUrl ?? "",
            displayName: pair.target.channelName,
            thumbnail: pair.target.channelThumbnail,
            status: "confirmed",
            method: "user",
            evidence: "You combined these cards.",
            decidedByUser: true
        )
    }

    /// Other cards with the same name, most likely the same person added twice.
    static func sameName(as person: AlsoOnPerson, in people: [AlsoOnPerson]) -> [AlsoOnPerson] {
        let name = person.name.trimmingCharacters(in: .whitespaces).lowercased()
        return people.filter { $0.id != person.id && $0.name.trimmingCharacters(in: .whitespaces).lowercased() == name }
    }

    static func buildPeople(channels: [Channel], links: [IdentityLink], scans: [IdentityScan]) -> [AlsoOnPerson] {
        let sources = channels.filter { isPersonSource($0) }
        let sourceIds = Set(sources.map { $0.id })
        var keyToSource: [String: String] = [:]
        for ch in sources {
            for key in channelKeys(ch) where keyToSource[key] == nil { keyToSource[key] = ch.id }
        }
        for ch in sources { keyToSource[mergeKeyPrefix + ch.id] = ch.id }

        // The same account followed in two agents is one person.
        var parent: [String: String] = [:]
        for ch in sources { parent[ch.id] = ch.id }
        func find(_ id: String) -> String {
            var root = id
            while let next = parent[root], next != root { root = next }
            parent[id] = root
            return root
        }
        func join(_ a: String, _ b: String) {
            let ra = find(a)
            let rb = find(b)
            if ra != rb { parent[rb] = ra }
        }
        for ch in sources {
            for key in channelKeys(ch) {
                if let other = keyToSource[key], other != ch.id { join(ch.id, other) }
            }
        }
        // Confirmed links that point at another followed source join the two.
        for link in links where link.isConfirmed && sourceIds.contains(link.channelId) {
            for key in linkKeys(link) {
                if let other = keyToSource[key], other != link.channelId { join(link.channelId, other) }
            }
        }

        var groups: [String: [Channel]] = [:]
        var order: [String] = []
        for ch in sources {
            let root = find(ch.id)
            if groups[root] == nil { order.append(root) }
            groups[root, default: []].append(ch)
        }

        var scanById: [String: IdentityScan] = [:]
        for scan in scans { scanById[scan.channelId] = scan }
        let linksByChannel = Dictionary(grouping: links, by: { $0.channelId })

        var people: [AlsoOnPerson] = []
        for root in order {
            let group = groups[root] ?? []
            // Highest priority first; ties keep their order.
            let sorted = group.enumerated().sorted { a, b in
                let pa = a.element.priority ?? 3
                let pb = b.element.priority ?? 3
                return pa != pb ? pa > pb : a.offset < b.offset
            }.map { $0.element }
            guard let lead = sorted.first else { continue }
            var groupKeys = Set(group.flatMap { channelKeys($0) })
            for ch in group { groupKeys.insert(mergeKeyPrefix + ch.id) }

            var following: [AlsoOnFollowedAccount] = []
            var seenFollow = Set<String>()
            for ch in sorted {
                let platform = ch.sourcePlatform
                let key = channelKeys(ch).first ?? ch.id
                let tag = platform.rawValue + ":" + key
                if seenFollow.contains(tag) { continue }
                seenFollow.insert(tag)
                following.append(AlsoOnFollowedAccount(
                    key: key, platform: platform, label: sourceLabel(ch), url: ch.channelUrl ?? "", channel: ch
                ))
            }

            let groupLinks = group.flatMap { linksByChannel[$0.id] ?? [] }
            let rejected = Set(groupLinks.filter { $0.isRejected }.map { $0.matchKey })
            let confirmedKeys = Set(groupLinks.filter { $0.isConfirmed }.map { $0.matchKey })
            // Confirmed first so a key confirmed by one source isn't also shown as possible.
            let ordered = groupLinks.filter { $0.isConfirmed } + groupLinks.filter { !$0.isConfirmed }
            var also: [AlsoOnFoundAccount] = []
            var possible: [AlsoOnFoundAccount] = []
            var seen = Set<String>()
            for link in ordered {
                // Cards combined by hand: the link only joins them, it's not an account.
                if isMergeLink(link) { continue }
                if link.isRejected || rejected.contains(link.matchKey) { continue }
                if linkKeys(link).contains(where: { groupKeys.contains($0) }) || seen.contains(link.matchKey) { continue }
                if !link.isConfirmed && confirmedKeys.contains(link.matchKey) { continue }
                seen.insert(link.matchKey)
                let platform = link.sourcePlatform
                let item = AlsoOnFoundAccount(
                    isConfirmed: link.isConfirmed,
                    key: link.matchKey,
                    platform: platform,
                    label: accountLabel(platform: platform, handle: link.handle, url: link.url),
                    url: link.url,
                    link: link
                )
                if item.isConfirmed { also.append(item) } else { possible.append(item) }
            }

            let groupScans = group.compactMap { scanById[$0.id] }
            var agentIds: [String] = []
            for ch in sorted where !agentIds.contains(ch.agentId) { agentIds.append(ch.agentId) }

            // A source added moments ago (a YouTube link before its first run)
            // has no name or picture yet; a confirmed match on another
            // platform stands in.
            let named = sorted.first(where: { !($0.channelName ?? "").isEmpty })
            let matchName = also.first(where: { !($0.link.displayName ?? "").isEmpty })?.link.displayName
            let matchPicture = also.first(where: { !($0.link.thumbnail ?? "").isEmpty })?.link.thumbnail
            let personName: String
            if let named {
                personName = cleanName(named.channelName, fallback: sourceLabel(named))
            } else {
                personName = matchName ?? cleanName(lead.channelName, fallback: sourceLabel(lead))
            }

            people.append(AlsoOnPerson(
                id: root,
                name: personName,
                thumbnail: sorted.first(where: { !($0.channelThumbnail ?? "").isEmpty })?.channelThumbnail ?? matchPicture,
                sources: sorted,
                agentIds: agentIds,
                following: following,
                also: also,
                possible: possible,
                lastScannedAt: groupScans.map { $0.scannedAt }.max(),
                scanErrors: groupScans.compactMap { $0.error }.filter { !$0.isEmpty },
                merges: groupLinks.filter { isMergeLink($0) && $0.isConfirmed }
            ))
        }

        return people.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
