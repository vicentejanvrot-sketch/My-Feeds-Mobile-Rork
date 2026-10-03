import Foundation

/// Which kinds of posts a collection keeps, per platform. Stored in
/// agents.content_types: a key set to false leaves that kind out, anything
/// missing is kept. YouTube Shorts and live videos use include_shorts and
/// include_live. run-agent applies these. Keep in sync with
/// src/lib/contentTypes.ts (web) and expo/lib/contentTypes.ts.
nonisolated enum ContentTypes {
    struct Option: Identifiable, Hashable, Sendable {
        let key: String
        let label: String
        let help: String
        var id: String { key }
    }

    struct Group: Identifiable, Hashable, Sendable {
        let platform: SourcePlatform
        let options: [Option]
        var id: String { platform.rawValue }
    }

    static let groups: [Group] = [
        Group(platform: .instagram, options: [
            Option(key: "instagram_reels", label: "Reels", help: "Short videos"),
            Option(key: "instagram_posts", label: "Photo and carousel posts", help: "Single photos and multi-photo posts"),
        ]),
        Group(platform: .tiktok, options: [
            Option(key: "tiktok_videos", label: "Videos", help: "Regular TikTok videos"),
            Option(key: "tiktok_photos", label: "Photo slideshows", help: "Posts made of photos"),
        ]),
        Group(platform: .facebook, options: [
            Option(key: "facebook_videos", label: "Videos and reels", help: "Includes saved live videos"),
            Option(key: "facebook_posts", label: "Photo and text posts", help: "Everything without a video"),
        ]),
    ]

    static let liveNote = "Instagram and TikTok live streams can't be included: they leave the account's posts when they end, so there's nothing for My Feeds to collect."

    /// The app's decoder turns "instagram_reels" into "instagramReels";
    /// this puts the stored keys back as the database has them.
    static func normalized(_ types: [String: Bool]?) -> [String: Bool] {
        var result: [String: Bool] = [:]
        for (key, value) in types ?? [:] {
            var snake = ""
            for character in key {
                if character.isUppercase {
                    snake += "_" + character.lowercased()
                } else {
                    snake.append(character)
                }
            }
            result[snake] = value
        }
        return result
    }

    static func isOn(_ types: [String: Bool]?, _ key: String) -> Bool {
        normalized(types)[key] != false
    }
}
