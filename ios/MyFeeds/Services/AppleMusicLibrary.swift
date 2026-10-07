import Foundation
import MusicKit

/// Apple Music "Add to playlist" on iPhone, with Apple's MusicKit framework:
/// adds every song of a release to the user's "My Feeds" playlist in their
/// Apple Music library. The songs stay in Apple Music, so the user listens (and
/// downloads for offline) in the Apple Music app. The web and Android apps do
/// the same through the apple-music edge function; all of them look for the
/// playlist by name, so they share one "My Feeds" playlist.
///
/// Needs MusicKit turned on for the app's identifier in the Apple Developer
/// account, and an Apple Music subscription on the user's side.
enum AppleMusicLibrary {
    static let playlistName = "My Feeds"
    private static let playlistDescription = String(localized: "Songs added from My Feeds.", bundle: .appStrings)
    private static let playlistIdKey = "appleMusicPlaylistId"

    /// Adds the release's songs and returns how many were added.
    /// albumId: the release's Apple id (items.video_id "apple_music:<id>" works too).
    static func addRelease(albumId raw: String) async throws -> Int {
        let albumId = raw.hasPrefix("apple_music:") ? String(raw.dropFirst("apple_music:".count)) : raw

        switch await MusicAuthorization.request() {
        case .authorized:
            break
        case .denied, .restricted:
            throw AppleMusicLibraryError.message(String(localized: "Allow My Feeds to use Apple Music in the Settings app (Settings > My Feeds).", bundle: .appStrings))
        default:
            throw AppleMusicLibraryError.cancelled
        }

        let subscription = try? await MusicSubscription.current
        if let subscription, !subscription.hasCloudLibraryEnabled {
            throw AppleMusicLibraryError.message(
                subscription.canPlayCatalogContent
                    ? String(localized: "Turn on Sync Library in Settings > Music to add songs to your library.", bundle: .appStrings)
                    : String(localized: "Adding songs to your library needs an Apple Music subscription.", bundle: .appStrings)
            )
        }

        let request = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: MusicItemID(albumId))
        guard let album = try await request.response().items.first else {
            throw AppleMusicLibraryError.message(String(localized: "This release isn't available in your country's Apple Music.", bundle: .appStrings))
        }
        let detailed = try await album.with([.tracks])
        let tracks = Array(detailed.tracks ?? [])
        guard !tracks.isEmpty else { throw AppleMusicLibraryError.message(String(localized: "No songs found for this release.", bundle: .appStrings)) }

        if var playlist = try await existingPlaylist() {
            for track in tracks {
                playlist = try await MusicLibrary.shared.add(track, to: playlist)
            }
        } else {
            let playlist = try await MusicLibrary.shared.createPlaylist(
                name: playlistName,
                description: playlistDescription,
                authorDisplayName: nil,
                items: tracks
            )
            UserDefaults.standard.set(playlist.id.rawValue, forKey: playlistIdKey)
        }
        return tracks.count
    }

    /// The "My Feeds" playlist: the one this phone made, else one with that name.
    private static func existingPlaylist() async throws -> Playlist? {
        if let saved = UserDefaults.standard.string(forKey: playlistIdKey) {
            var byId = MusicLibraryRequest<Playlist>()
            byId.filter(matching: \.id, equalTo: MusicItemID(saved))
            if let found = try await byId.response().items.first { return found }
        }
        var byName = MusicLibraryRequest<Playlist>()
        byName.filter(text: playlistName)
        let found = try await byName.response().items.first { $0.name == playlistName }
        if let found { UserDefaults.standard.set(found.id.rawValue, forKey: playlistIdKey) }
        return found
    }
}

nonisolated enum AppleMusicLibraryError: LocalizedError {
    case cancelled
    case message(String)

    var errorDescription: String? {
        switch self {
        case .cancelled: return String(localized: "Apple Music access wasn't allowed.", bundle: .appStrings)
        case .message(let text): return text
        }
    }
}
