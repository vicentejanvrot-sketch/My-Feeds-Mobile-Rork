import SwiftUI

/// Download icon for the post reader and the video player: saves the item on the
/// phone for offline use (see DownloadStore). Shows the progress while saving and
/// a check once it's saved; tapping the check offers to remove it.
/// For a YouTube video it first explains that the video itself can't be saved.
struct DownloadButton: View {
    let itemId: String
    var hasAudio = false
    /// Set for YouTube videos: the video can't be downloaded, only its summary.
    var youtubeVideoId: String? = nil
    var iconSize: CGFloat = 17

    @Environment(ToastCenter.self) private var toasts
    @Environment(\.openURL) private var openURL
    @State private var confirmRemove = false
    @State private var explainYouTube = false

    private var store: DownloadStore { DownloadStore.shared }

    var body: some View {
        Group {
            if let progress = store.progress[itemId] {
                Text((progress).formatted(.percent.precision(.fractionLength(0))))
                    .font(.system(size: 12, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Downloading, \(Int((progress * 100).rounded())) percent")
            } else if store.isDownloaded(itemId) {
                Button {
                    confirmRemove = true
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: iconSize + 2, weight: .semibold))
                        .foregroundStyle(Theme.success)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Downloaded. Remove download")
            } else {
                Button {
                    if youtubeVideoId != nil {
                        explainYouTube = true
                    } else {
                        start()
                    }
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: iconSize + 2, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Download for offline")
                // YouTube only lets its videos play in its own player, so the video can't be kept
                // on the phone. Say so before saving, and point to YouTube's own Download instead.
                .alert("This video can't be downloaded", isPresented: $explainYouTube) {
                    Button("Cancel", role: .cancel) {}
                    Button("Open YouTube") {
                        if let id = youtubeVideoId, let url = URL(string: "https://www.youtube.com/watch?v=\(id)") {
                            openURL(url)
                        }
                    }
                    Button("Save summary") { start() }
                } message: {
                    Text("YouTube only lets its videos play in its own player, so My Feeds can't save this video to your phone.\n\nSave summary keeps the summary and key moments for offline reading. To watch the video offline, open it in the YouTube app and use Download there (needs YouTube Premium).")
                }
            }
        }
        .onAppear { store.load() }
        .alert("Remove download?", isPresented: $confirmRemove) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                store.delete(itemId: itemId)
                toasts.show(String(localized: "Download removed", bundle: .appStrings))
            }
        } message: {
            Text("It stays in your feed. Only the copy on this phone is deleted.")
        }
    }

    private func start() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            do {
                try await store.download(itemId: itemId)
                // Downloads stay inside My Feeds (not Photos or Files), so say where to find them.
                toasts.show(hasAudio
                    ? String(localized: "Episode saved inside My Feeds for offline listening. See it in this app's Settings tab > Downloads.", bundle: .appStrings)
                    : youtubeVideoId != nil
                        ? String(localized: "Summary saved inside My Feeds for offline reading. The video still needs a connection. See it in this app's Settings tab > Downloads.", bundle: .appStrings)
                        : String(localized: "Saved inside My Feeds for offline reading. See it in this app's Settings tab > Downloads.", bundle: .appStrings))
            } catch {
                toasts.show(error.localizedDescription, type: .error)
            }
        }
    }
}
