import Foundation
import Supabase

/// Instagram signs every photo and video link with an expiry time (the `oe`
/// parameter, a hex Unix time), usually 2 to 3 days after the post was saved.
/// After that its CDN refuses the link and the video won't play. These helpers
/// spot expired links and ask the refresh-media function for new ones.
/// Same logic on the web (src/lib/expiredMedia.ts) and Expo (lib/expired-media.ts).
nonisolated enum ExpiredMedia {
    /// Links that expire within this long count as expired, so a video doesn't stop part way.
    static let margin: TimeInterval = 10 * 60

    /// When a link stops working, from the Instagram link's `oe` parameter, also
    /// when it sits inside our media-proxy link's `u` parameter. nil: no expiry.
    static func expiresAt(_ raw: String?) -> Date? {
        guard let raw, var components = URLComponents(string: raw) else { return nil }
        if let inner = components.queryItems?.first(where: { $0.name == "u" })?.value,
           let innerComponents = URLComponents(string: inner) {
            components = innerComponents
        }
        guard let oe = components.queryItems?.first(where: { $0.name == "oe" })?.value,
              let seconds = UInt64(oe, radix: 16) else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }

    static func hasExpired(_ media: [ItemMedia]?) -> Bool {
        guard let media else { return false }
        let limit = Date().addingTimeInterval(margin)
        return media.contains { m in
            [m.url, m.videoUrl].contains { link in
                guard let at = expiresAt(link) else { return false }
                return at < limit
            }
        }
    }
}

private nonisolated struct RefreshMediaResponse: Decodable {
    var media: [ItemMedia]?
    var thumbnailUrl: String?
    var refreshed: Bool?
}

extension SupabaseService {
    /// An Instagram item with expired links gets new ones (saved on the item for
    /// every device). Anything else, or a failed renewal, comes back unchanged.
    func withFreshMedia(_ item: FeedItem) async -> FeedItem {
        guard item.platform == "instagram", ExpiredMedia.hasExpired(item.media) else { return item }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            let response: RefreshMediaResponse = try await client.functions.invoke(
                "refresh-media",
                options: FunctionInvokeOptions(body: ["itemId": item.id]),
                decoder: decoder
            )
            guard response.refreshed == true, let media = response.media, !media.isEmpty else { return item }
            var fresh = item
            fresh.media = media
            if let thumbnail = response.thumbnailUrl { fresh.thumbnailUrl = thumbnail }
            return fresh
        } catch {
            return item
        }
    }
}
