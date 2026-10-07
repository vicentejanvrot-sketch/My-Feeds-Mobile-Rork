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

    private var addLabel: String {
        switch kind {
        case "video": return String(localized: "Add video to YouTube Music")
        case "single": return String(localized: "Add song to YouTube Music")
        case "ep": return String(localized: "Add EP to YouTube Music")
        default: return String(localized: "Add album to YouTube Music")
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
                         ? String(localized: "Added to YouTube Music")
                         : account.isConnected ? addLabel : String(localized: "Connect YouTube to add it"))
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
                    toasts.show(String(localized: "YouTube connected"))
                }
                state = .adding
                let added = try await account.addToMusicPlaylist(videoIds: videoIds)
                state = .added
                toasts.show(added == 0
                    ? String(localized: "Already in your \"My Feeds\" playlist")
                    : kind == "video"
                        ? String(localized: "Added \(added) videos to \"My Feeds\" in YouTube Music")
                        : String(localized: "Added \(added) songs to \"My Feeds\" in YouTube Music"))
            } catch YouTubeAccountError.cancelled {
                state = .idle
            } catch {
                state = .idle
                toasts.show(error.localizedDescription, type: .error)
            }
        }
    }
}
