import SwiftUI

/// Everything saved on this phone for offline use, newest first. Works with no
/// connection: the list and the files are read from the phone. Remove one item
/// with the trash icon, or everything with "Delete all".
struct DownloadsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toasts
    @State private var toRemove: DownloadEntry?
    @State private var confirmDeleteAll = false

    private var store: DownloadStore { DownloadStore.shared }

    var body: some View {
        let list = store.sortedEntries
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if list.isEmpty {
                    emptyState
                } else {
                    Text("\(list.count) items · \(DownloadStore.formatBytes(store.totalBytes)) on this phone. Posts are saved with their photos and videos, and podcasts with the episode. YouTube videos still need a connection.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .lineSpacing(3)
                        .padding(.bottom, 4)
                    ForEach(list) { entry in
                        row(entry)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .navigationTitle("Downloads")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            if !list.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Delete all") { confirmDeleteAll = true }
                        .foregroundStyle(Theme.destructive)
                }
            }
        }
        .onAppear { store.load() }
        .alert("Delete all downloads?", isPresented: $confirmDeleteAll) {
            Button("Cancel", role: .cancel) {}
            Button("Delete all", role: .destructive) {
                store.deleteAll()
                toasts.show(String(localized: "All downloads deleted", bundle: .appStrings))
            }
        } message: {
            Text("Frees \(DownloadStore.formatBytes(store.totalBytes)) on this phone. Your feeds aren't affected.")
        }
        .alert("Remove download?", isPresented: Binding(
            get: { toRemove != nil },
            set: { if !$0 { toRemove = nil } }
        )) {
            Button("Cancel", role: .cancel) { toRemove = nil }
            Button("Remove", role: .destructive) {
                if let entry = toRemove {
                    store.delete(itemId: entry.itemId)
                    toasts.show(String(localized: "Download removed", bundle: .appStrings))
                }
                toRemove = nil
            }
        } message: {
            Text(toRemove?.title ?? String(localized: "This item", bundle: .appStrings))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 36))
                .foregroundStyle(Theme.textMuted)
            Text("Nothing downloaded yet")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("Open a post, podcast episode or video and tap the download icon at the top. It stays on this phone so you can read or listen with no connection.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, 16)
    }

    private func row(_ entry: DownloadEntry) -> some View {
        let platform = SourcePlatform(raw: entry.platform ?? "youtube")
        return HStack(spacing: 12) {
            Button {
                router.openPost(itemId: entry.itemId)
            } label: {
                HStack(spacing: 12) {
                    Group {
                        if let file = entry.thumbFile {
                            AsyncImage(url: store.fileURL(itemId: entry.itemId, file: file)) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    Theme.input
                                }
                            }
                        } else {
                            ZStack {
                                Theme.input
                                PlatformBadge(platform: platform)
                            }
                        }
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(.rect(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title ?? String(localized: "Untitled", bundle: .appStrings))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        HStack(spacing: 6) {
                            PlatformBadge(platform: platform)
                            if entry.hasAudio {
                                Image(systemName: "headphones")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Text(meta(entry))
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                toRemove = entry
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 40, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove download")
        }
        .padding(10)
        .background(Theme.card)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    private func meta(_ entry: DownloadEntry) -> String {
        let size = DownloadStore.formatBytes(entry.bytes)
        let saved = String(localized: "saved \(entry.savedAt.formatted(.relative(presentation: .named)))", bundle: .appStrings)
        if let name = entry.channelName, !name.isEmpty { return "\(name) · \(size) · \(saved)" }
        return "\(size) · \(saved)"
    }
}
