import SwiftUI

/// Download icon for the post reader and the video player: saves the item on the
/// phone for offline use (see DownloadStore). Shows the progress while saving and
/// a check once it's saved; tapping the check offers to remove it.
struct DownloadButton: View {
    let itemId: String
    var hasAudio = false
    var iconSize: CGFloat = 17

    @Environment(ToastCenter.self) private var toasts
    @State private var confirmRemove = false

    private var store: DownloadStore { DownloadStore.shared }

    var body: some View {
        Group {
            if let progress = store.progress[itemId] {
                Text("\(Int((progress * 100).rounded()))%")
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
                    start()
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: iconSize + 2, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Download for offline")
            }
        }
        .onAppear { store.load() }
        .alert("Remove download?", isPresented: $confirmRemove) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                store.delete(itemId: itemId)
                toasts.show("Download removed")
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
                toasts.show(hasAudio ? "Episode saved for offline listening" : "Saved for offline reading")
            } catch {
                toasts.show(error.localizedDescription, type: .error)
            }
        }
    }
}
