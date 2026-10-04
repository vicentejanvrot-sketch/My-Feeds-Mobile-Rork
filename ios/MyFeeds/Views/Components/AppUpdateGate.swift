import SwiftUI

/// "New version available" banner when the App Store has a newer version, and
/// a screen that blocks the app when this version is below the minimum
/// (app_releases). Also saves this phone's version when the app opens.
/// See AppVersionService.
struct AppUpdateGate: View {
    let userId: String

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("app.updateDismissed") private var dismissedVersion = ""
    @State private var update: AppVersionService.UpdateInfo?

    var body: some View {
        Group {
            if let update {
                if update.required {
                    blocker(update)
                } else if dismissedVersion != update.latestVersion {
                    banner(update)
                }
            }
        }
        .task(id: userId) { await refresh() }
        // Back in the app (e.g. after a long time away): check again.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refresh() } }
        }
    }

    private func refresh() async {
        await AppVersionService.reportInstall(userId: userId)
        update = await AppVersionService.checkForUpdate()
    }

    private func banner(_ info: AppVersionService.UpdateInfo) -> some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text("New version available")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Version \(info.latestVersion) is ready to install.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 4)
                Button("Update") { openURL(info.storeURL) }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Theme.accent, in: Capsule())
                    .buttonStyle(.plain)
                // "Later" hides the banner until an even newer version comes out.
                Button {
                    withAnimation { dismissedVersion = info.latestVersion }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Later")
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Theme.card, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func blocker(_ info: AppVersionService.UpdateInfo) -> some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(Theme.accent)
                Text("Update My Feeds")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                Text("This version (\(AppVersionService.appVersion ?? "")) is no longer supported. Update to version \(info.latestVersion) to keep using My Feeds.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                Button {
                    openURL(info.storeURL)
                } label: {
                    Text("Update now")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Theme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
            .padding(.horizontal, 28)
        }
    }
}
