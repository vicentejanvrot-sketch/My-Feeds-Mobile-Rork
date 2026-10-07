import AVFoundation
import Foundation
import Observation

/// One item saved on this phone for offline use.
nonisolated struct DownloadEntry: Codable, Hashable, Sendable, Identifiable {
    let itemId: String
    var title: String?
    var platform: String?
    var channelName: String?
    /// File name inside the item's folder, or nil.
    var thumbFile: String?
    var savedAt: Date
    var bytes: Int64
    var hasAudio: Bool

    var id: String { itemId }
}

/// Offline downloads: keeps an item on the phone so it can be read or played
/// with no connection (plane, road trip). What's kept: the text, the AI summary,
/// key moments, photos and cover art, full podcast episodes, and post videos
/// (X, Instagram, Facebook, LinkedIn, Reddit). YouTube videos can't be
/// downloaded: YouTube only allows its own player, so they still need a
/// connection. Same behaviour as the Expo app's lib/downloads.ts.
///
/// Files live in Application Support/Downloads (left out of iCloud backups,
/// since they can be downloaded again):
///   index.json            the list of downloads
///   <itemId>/item.json    the item, with "local:<file>" in place of links
///   <itemId>/<files>      thumb, media-0, audio, video-0.mp4
/// Links are saved as "local:<file>" and resolved on read, because the app's
/// folder path changes when iOS updates the app.
@Observable
final class DownloadStore {
    static let shared = DownloadStore()

    private(set) var entries: [String: DownloadEntry] = [:]
    /// 0...1 while a download is running.
    private(set) var progress: [String: Double] = [:]
    @ObservationIgnored private var loaded = false

    private static let localPrefix = "local:"

    private let root: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Downloads", isDirectory: true)
    }()

    private var indexURL: URL { root.appendingPathComponent("index.json") }

    private init() {}

    var sortedEntries: [DownloadEntry] {
        entries.values.sorted { $0.savedAt > $1.savedAt }
    }

    var totalBytes: Int64 { entries.values.reduce(0) { $0 + $1.bytes } }

    func isDownloaded(_ itemId: String) -> Bool { entries[itemId] != nil }

    func folder(for itemId: String) -> URL {
        let safe = itemId.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression)
        return root.appendingPathComponent(safe, isDirectory: true)
    }

    func fileURL(itemId: String, file: String) -> URL {
        folder(for: itemId).appendingPathComponent(file)
    }

    /// Reads the list of downloads from the phone (once).
    func load() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: indexURL),
              let list = try? Self.decoder.decode([DownloadEntry].self, from: data) else { return }
        entries = Dictionary(uniqueKeysWithValues: list.map { ($0.itemId, $0) })
    }

    // MARK: - Download

    /// Saves an item on the phone. Photos that fail are left as links; a podcast
    /// episode that fails cancels the download.
    func download(itemId: String) async throws {
        load()
        guard progress[itemId] == nil else { return }
        progress[itemId] = 0
        defer { progress[itemId] = nil }

        let folder = folder(for: itemId)
        let fm = FileManager.default
        do {
            var item = try await SupabaseService.shared.fetchItem(id: itemId)

            try? fm.removeItem(at: folder)
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            excludeFromBackup(root)

            var media = item.media ?? []
            let audioIndex = media.firstIndex { $0.type == "audio" && ($0.audioUrl?.isEmpty == false) }
            // The post's own videos (not a quoted post's), as MP4 files.
            let videoIndexes = media.indices.filter { i in
                !media[i].isEmbed && media[i].videoUrl.flatMap(Self.httpURL) != nil
            }

            // Photos and cover art first (small), then the episode (large, shows progress).
            var images: [(url: URL, file: String, target: ImageTarget)] = []
            if let raw = item.thumbnailUrl, let url = Self.httpURL(raw) {
                images.append((url, "thumb" + Self.fileExtension(of: url, fallback: ".jpg"), .thumbnail))
            }
            for (i, m) in media.enumerated() {
                if m.isEmbed {
                    // A quoted post or X article: its picture (the post itself is a link).
                    if let raw = m.image, let url = Self.httpURL(raw) {
                        images.append((url, "embed-\(i)" + Self.fileExtension(of: url, fallback: ".jpg"), .embed(i)))
                    }
                } else if let raw = m.url, let url = Self.httpURL(raw) {
                    images.append((url, "media-\(i)" + Self.fileExtension(of: url, fallback: ".jpg"), .media(i)))
                }
            }

            let share = audioIndex == nil && videoIndexes.isEmpty ? 1.0 : 0.1
            let heavy = Double((audioIndex == nil ? 0 : 1) + videoIndexes.count)
            var savedThumb: String?
            var firstPhoto: String?
            for (n, image) in images.enumerated() {
                if (try? await FileFetcher.fetch(image.url, to: folder.appendingPathComponent(image.file), progress: nil)) != nil {
                    let local = Self.localPrefix + image.file
                    switch image.target {
                    case .thumbnail:
                        item.thumbnailUrl = local
                        savedThumb = image.file
                    case .media(let i):
                        media[i].url = local
                        if firstPhoto == nil { firstPhoto = image.file }
                    case .embed(let i):
                        media[i].image = local
                        if firstPhoto == nil { firstPhoto = image.file }
                    }
                }
                progress[itemId] = Double(n + 1) / Double(max(images.count, 1)) * share
            }

            if let audioIndex, let raw = media[audioIndex].audioUrl, let url = URL(string: raw) {
                let file = "audio" + Self.fileExtension(of: url, fallback: ".mp3")
                do {
                    let span = (1 - share) / max(heavy, 1)
                    try await FileFetcher.fetch(url, to: folder.appendingPathComponent(file)) { [weak self] fraction in
                        Task { @MainActor in
                            guard let self, self.progress[itemId] != nil else { return }
                            self.progress[itemId] = share + fraction * span
                        }
                    }
                } catch {
                    throw DownloadError.message(String(localized: "Couldn't download the episode."))
                }
                media[audioIndex].audioUrl = Self.localPrefix + file
            }

            // Videos, one after another, sharing what's left of the progress bar.
            var done = audioIndex == nil ? 0.0 : 1.0
            for i in videoIndexes {
                let base = share + done / heavy * (1 - share)
                let span = (1 - share) / heavy
                done += 1
                if let file = await downloadVideo(media[i], index: i, into: folder, progress: { [weak self] fraction in
                    Task { @MainActor in
                        guard let self, self.progress[itemId] != nil else { return }
                        self.progress[itemId] = base + fraction * span
                    }
                }) {
                    media[i].videoUrl = Self.localPrefix + file
                    media[i].hlsUrl = nil
                }
                // A video link that has expired (Facebook's do after a few days)
                // stays a link; the rest of the post is still saved.
            }

            item.media = media
            let data = try JSONEncoder().encode(item)
            try data.write(to: folder.appendingPathComponent("item.json"), options: .atomic)

            let entry = DownloadEntry(
                itemId: itemId,
                title: item.title,
                platform: item.platform,
                channelName: item.channelName,
                thumbFile: savedThumb ?? firstPhoto,
                savedAt: Date(),
                bytes: folderSize(folder),
                hasAudio: audioIndex != nil
            )
            entries[itemId] = entry
            saveIndex()
        } catch let error as DownloadError {
            try? fm.removeItem(at: folder)
            throw error
        } catch {
            try? fm.removeItem(at: folder)
            throw DownloadError.message(String(localized: "Couldn't download this item. Check your connection."))
        }
    }

    /// The saved copy of an item, with links pointing at the files on the phone.
    func localItem(_ itemId: String) -> FeedItem? {
        load()
        guard entries[itemId] != nil,
              let data = try? Data(contentsOf: fileURL(itemId: itemId, file: "item.json")),
              var item = try? JSONDecoder().decode(FeedItem.self, from: data) else { return nil }
        item.thumbnailUrl = resolve(item.thumbnailUrl, itemId: itemId)
        item.media = item.media?.map { m in
            var m = m
            m.url = resolve(m.url, itemId: itemId)
            m.image = resolve(m.image, itemId: itemId)
            m.audioUrl = resolve(m.audioUrl, itemId: itemId)
            m.videoUrl = resolve(m.videoUrl, itemId: itemId)
            return m
        }
        return item
    }

    func delete(itemId: String) {
        load()
        try? FileManager.default.removeItem(at: folder(for: itemId))
        entries[itemId] = nil
        saveIndex()
    }

    func deleteAll() {
        try? FileManager.default.removeItem(at: root)
        entries = [:]
        saveIndex()
    }

    // MARK: - Videos

    /// Saves one post video as video-<index>.mp4 and returns the file name, or
    /// nil if it couldn't be fetched. Instagram's comes straight from its CDN.
    /// Reddit keeps the sound in a separate file, so that is fetched too and
    /// joined with the picture into one MP4 on the phone.
    private func downloadVideo(
        _ media: ItemMedia,
        index: Int,
        into folder: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async -> String? {
        guard let raw = media.videoUrl, let stored = Self.httpURL(raw) else { return nil }
        let file = "video-\(index).mp4"
        let destination = folder.appendingPathComponent(file)
        let sources = [Self.directVideoURL(stored), stored].compactMap { $0 }
        var saved = false
        for url in sources {
            if (try? await FileFetcher.fetch(url, to: destination, progress: progress)) != nil {
                saved = true
                break
            }
        }
        guard saved else { return nil }

        let audioFile = folder.appendingPathComponent("video-\(index)-audio.mp4")
        for url in Self.redditAudioCandidates(stored) {
            guard (try? await FileFetcher.fetch(url, to: audioFile, progress: nil)) != nil else { continue }
            let joined = folder.appendingPathComponent("video-\(index)-joined.mp4")
            if await Self.join(video: destination, audio: audioFile, to: joined) {
                try? FileManager.default.removeItem(at: destination)
                try? FileManager.default.moveItem(at: joined, to: destination)
            }
            try? FileManager.default.removeItem(at: audioFile)
            break
        }
        return file
    }

    /// Instagram videos are stored behind our media proxy; the file itself
    /// downloads straight from Instagram's CDN.
    private static func directVideoURL(_ url: URL) -> URL? {
        guard url.path.hasSuffix("/functions/v1/media-proxy"),
              let inner = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "u" })?.value,
              let direct = URL(string: inner),
              let host = direct.host?.lowercased(),
              host.hasSuffix(".cdninstagram.com") || host.hasSuffix(".fbcdn.net") else { return nil }
        return direct
    }

    /// Reddit's MP4 has no sound; its sound sits next to it as DASH_AUDIO_128.mp4 (or older names).
    private static func redditAudioCandidates(_ url: URL) -> [URL] {
        guard url.host?.lowercased() == "v.redd.it", let id = url.pathComponents.dropFirst().first else { return [] }
        return ["DASH_AUDIO_128.mp4", "DASH_AUDIO_64.mp4", "DASH_audio.mp4", "audio"]
            .compactMap { URL(string: "https://v.redd.it/\(id)/\($0)") }
    }

    /// Joins a silent video and its sound into one MP4, without re-encoding.
    private static func join(video: URL, audio: URL, to output: URL) async -> Bool {
        do {
            let videoAsset = AVURLAsset(url: video)
            let audioAsset = AVURLAsset(url: audio)
            guard let videoTrack = try await videoAsset.loadTracks(withMediaType: .video).first,
                  let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first else { return false }
            let videoDuration = try await videoAsset.load(.duration)
            let audioDuration = try await audioAsset.load(.duration)

            let composition = AVMutableComposition()
            guard let videoOut = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
                  let audioOut = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { return false }
            try videoOut.insertTimeRange(CMTimeRange(start: .zero, duration: videoDuration), of: videoTrack, at: .zero)
            videoOut.preferredTransform = try await videoTrack.load(.preferredTransform)
            try audioOut.insertTimeRange(
                CMTimeRange(start: .zero, duration: CMTimeMinimum(videoDuration, audioDuration)),
                of: audioTrack,
                at: .zero
            )

            guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else { return false }
            try? FileManager.default.removeItem(at: output)
            try await export.export(to: output, as: .mp4)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Helpers

    private enum ImageTarget {
        case thumbnail
        case media(Int)
        case embed(Int)
    }

    private func resolve(_ value: String?, itemId: String) -> String? {
        guard let value, value.hasPrefix(Self.localPrefix) else { return value }
        return fileURL(itemId: itemId, file: String(value.dropFirst(Self.localPrefix.count))).absoluteString
    }

    private func saveIndex() {
        let fm = FileManager.default
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        excludeFromBackup(root)
        if let data = try? Self.encoder.encode(Array(entries.values)) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }

    private func excludeFromBackup(_ url: URL) {
        var url = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    private func folderSize(_ folder: URL) -> Int64 {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.reduce(Int64(0)) { sum, file in
            sum + Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    private static func httpURL(_ raw: String) -> URL? {
        guard raw.hasPrefix("http://") || raw.hasPrefix("https://") else { return nil }
        let secure = raw.hasPrefix("http://") ? "https://" + raw.dropFirst("http://".count) : raw
        return URL(string: secure)
    }

    private static func fileExtension(of url: URL, fallback: String) -> String {
        let ext = url.pathExtension.lowercased()
        let known = ["jpg", "jpeg", "png", "webp", "gif", "heic", "mp3", "m4a", "aac", "wav", "mp4", "mov"]
        return known.contains(ext) ? "." + ext : fallback
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

nonisolated enum DownloadError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}

/// Downloads one file to a path, reporting progress. Kept off the main actor:
/// URLSession calls back on its own queue.
nonisolated enum FileFetcher {
    static func fetch(_ url: URL, to destination: URL, progress: (@Sendable (Double) -> Void)?) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let box = ObservationBox()
            let task = URLSession.shared.downloadTask(with: url) { temp, response, error in
                box.observation?.invalidate()
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let temp, let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    continuation.resume(throwing: DownloadError.message(String(localized: "Download failed.")))
                    return
                }
                do {
                    try? FileManager.default.removeItem(at: destination)
                    try FileManager.default.moveItem(at: temp, to: destination)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            if let progress {
                box.observation = task.progress.observe(\.fractionCompleted) { p, _ in
                    progress(p.fractionCompleted)
                }
            }
            task.resume()
        }
    }

    nonisolated private final class ObservationBox: @unchecked Sendable {
        var observation: NSKeyValueObservation?
    }
}
