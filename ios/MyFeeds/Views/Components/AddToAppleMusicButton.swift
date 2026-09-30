import SwiftUI

/// "Add to Apple Music" under the Apple Music player: puts the release's songs in
/// the user's "My Feeds" playlist in Apple Music (see AppleMusicLibrary), where
/// they can listen and download them for offline.
struct AddToAppleMusicButton: View {
    let albumId: String
    let single: Bool

    @Environment(ToastCenter.self) private var toasts
    @State private var state: AddState = .idle

    private enum AddState { case idle, adding, added }

    private static let appleMusicRed = Color(red: 250 / 255, green: 36 / 255, blue: 60 / 255)

    var body: some View {
        VStack(spacing: 6) {
            Button {
                add()
            } label: {
                HStack(spacing: 8) {
                    switch state {
                    case .adding:
                        ProgressView().tint(Self.appleMusicRed)
                    case .added:
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Self.appleMusicRed)
                    case .idle:
                        Image(systemName: "text.badge.plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Self.appleMusicRed)
                    }
                    Text(state == .added ? "Added to Apple Music" : single ? "Add song to Apple Music" : "Add album to Apple Music")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(state != .idle)

            Text("Goes into your \"My Feeds\" playlist. Needs an Apple Music subscription. Turn on Automatic Downloads in Apple Music to keep the songs offline.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private func add() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        state = .adding
        Task {
            do {
                let added = try await AppleMusicLibrary.addRelease(albumId: albumId)
                state = .added
                toasts.show("Added \(added) \(added == 1 ? "song" : "songs") to \"My Feeds\" in Apple Music")
            } catch AppleMusicLibraryError.cancelled {
                state = .idle
            } catch {
                state = .idle
                toasts.show(error.localizedDescription, type: .error)
            }
        }
    }
}
