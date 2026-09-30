import SwiftUI

/// "Add to YouTube Music" under the YouTube Music player: puts the songs (or the
/// music video) in the user's "My Feeds" playlist through their connected
/// YouTube account (see YouTubeAccount). Connects YouTube first if needed.
/// YouTube Music shows that playlist, where it can be downloaded with Premium.
struct AddToYouTubeMusicButton: View {
    let videoIds: [String]
    /// "single", "ep", "album" or "video"
    let kind: String

    @Environment(ToastCenter.self) private var toasts
    @State private var state: AddState = .idle

    private enum AddState { case idle, adding, added }

    private static let red = Color(red: 1, green: 0, blue: 51 / 255)

    private var account: YouTubeAccount { YouTubeAccount.shared }

    private var what: String {
        switch kind {
        case "video": return "video"
        case "single": return "song"
        case "ep": return "EP"
        default: return "album"
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Button {
                add()
            } label: {
                HStack(spacing: 8) {
                    if state == .adding || account.isConnecting {
                        ProgressView().tint(Self.red)
                    } else {
                        Image(systemName: state == .added ? "checkmark" : "text.badge.plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Self.red)
                    }
                    Text(state == .added
                         ? "Added to YouTube Music"
                         : account.isConnected ? "Add \(what) to YouTube Music" : "Connect YouTube to add it")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(state != .idle || account.isConnecting || videoIds.isEmpty)

            Text("Goes into your \"My Feeds\" playlist. With YouTube Music Premium you can download it for offline listening.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private func add() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            do {
                if !account.isConnected {
                    try await account.connect()
                    toasts.show("YouTube connected")
                }
                state = .adding
                let added = try await account.addToMusicPlaylist(videoIds: videoIds)
                state = .added
                let noun = kind == "video" ? (added == 1 ? "video" : "videos") : (added == 1 ? "song" : "songs")
                toasts.show(added > 0 ? "Added \(added) \(noun) to \"My Feeds\" in YouTube Music" : "Already in your \"My Feeds\" playlist")
            } catch YouTubeAccountError.cancelled {
                state = .idle
            } catch {
                state = .idle
                toasts.show(error.localizedDescription, type: .error)
            }
        }
    }
}
