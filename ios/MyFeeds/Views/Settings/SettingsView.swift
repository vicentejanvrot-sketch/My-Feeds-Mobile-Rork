import SwiftUI

struct SettingsView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(ToastCenter.self) private var toasts
    @Environment(VideoPrefs.self) private var prefs

    @State private var defaultEmail = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showQualityOptions = false
    @State private var aboutExpanded = false
    @State private var showDeleteConfirm = false

    var body: some View {
        @Bindable var prefs = prefs
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Settings")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.bottom, 20)

                profileCard

                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .tint(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    defaultEmailCard
                    videoPlaybackCard
                    biometricCard
                    aboutCard
                    dangerZoneCard
                    supportCard
                    saveButton
                }

                signOutButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 40)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
        .alert("Delete Account?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deleteAccount() }
        } message: {
            Text("This will permanently delete your account and all your data, including your agents, feeds, watch history, and saved settings. This cannot be undone.")
        }
    }

    // MARK: - Cards

    private var profileCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hsl: 199, 40, 14))
                    .frame(width: 46, height: 46)
                Image(systemName: "person")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("SIGNED IN AS")
                    .font(.system(size: 11))
                    .kerning(0.6)
                    .foregroundStyle(Theme.textSecondary)
                Text(auth.userEmail ?? "—")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(16)
        .cardStyle(radius: 12)
        .padding(.bottom, 20)
    }

    private var defaultEmailCard: some View {
        settingsCard(icon: "envelope", iconColor: Theme.accent, title: "Default Email",
                     description: "Pre-filled when adding email recipients to new agents.") {
            TextField("your@email.com", text: $defaultEmail)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textPrimary)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Theme.input)
                .clipShape(.rect(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
    }

    private var videoPlaybackCard: some View {
        @Bindable var prefs = prefs
        return settingsCard(icon: "display", iconColor: Theme.accent, title: "Video Playback",
                            description: "Configure default video playback settings. These sync across your devices via iCloud.") {
            Text("Default Video Quality")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 6)

            Button {
                withAnimation(.easeInOut(duration: 0.22)) { showQualityOptions.toggle() }
            } label: {
                HStack {
                    Text(prefs.quality.label)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .rotationEffect(.degrees(showQualityOptions ? 180 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Theme.input)
                .clipShape(.rect(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if showQualityOptions {
                VStack(spacing: 0) {
                    ForEach(VideoQuality.allCases, id: \.self) { quality in
                        Button {
                            prefs.quality = quality
                            withAnimation(.easeInOut(duration: 0.22)) { showQualityOptions = false }
                        } label: {
                            HStack {
                                Text(quality.label)
                                    .font(.system(size: 15, weight: prefs.quality == quality ? .semibold : .regular))
                                    .foregroundStyle(prefs.quality == quality ? .white : Theme.textPrimary)
                                Spacer()
                                if prefs.quality == quality {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(prefs.quality == quality ? Color(hsl: 199, 89, 48, alpha: 0.15) : .clear)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Theme.border).frame(height: 0.5)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Theme.input)
                .clipShape(.rect(cornerRadius: 8))
                .padding(.top, 4)
            }

            Text("Videos will start playing at this quality when available. This setting syncs across your devices via iCloud.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)
                .padding(.top, 6)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Keep screen on while playing")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Text("Prevents your device from auto-locking during video playback.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textMuted)
                }
                Spacer()
                Toggle("", isOn: $prefs.keepScreenOn)
                    .labelsHidden()
                    .tint(Theme.accent)
            }
            .padding(.top, 14)
        }
    }

    private var biometricCard: some View {
        @Bindable var prefs = prefs
        let biometryName = BiometricAuthService.biometryName
        let hasSavedCredentials = KeychainCredentialStore.savedCredentials() != nil
        return settingsCard(
            icon: biometryName == "Face ID" ? "faceid" : "touchid",
            iconColor: Theme.accent,
            title: "Quick Sign-In",
            description: "Use \(biometryName ?? "biometrics") to unlock your saved login instead of typing your password."
        ) {
            if biometryName == nil {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 13))
                    Text("Biometrics aren't available or aren't set up on this device.")
                        .font(.system(size: 13))
                }
                .foregroundStyle(Theme.textMuted)
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Enable \(biometryName ?? "biometrics") sign-in")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Text(hasSavedCredentials
                             ? "Sign out and back in with your password to update the saved login."
                             : "Sign in once with your password, then use \(biometryName ?? "biometrics") next time.")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textMuted)
                    }
                    Spacer()
                    Toggle("", isOn: $prefs.biometricEnabled)
                        .labelsHidden()
                        .tint(Theme.accent)
                }
                .padding(.top, 6)

                if prefs.biometricEnabled && !hasSavedCredentials {
                    Text("Save your login by signing out and signing back in with your password.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.warning)
                        .padding(.top, 8)
                } else if prefs.biometricEnabled && hasSavedCredentials {
                    Text("\(biometryName ?? "Biometrics") is ready. You'll see the option on the login screen.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.success)
                        .padding(.top, 8)
                }
            }
        }
    }

    private var aboutCard: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) { aboutExpanded.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("About background playback")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .rotationEffect(.degrees(aboutExpanded ? 180 : 0))
                }
                if aboutExpanded {
                    Text("Embedded YouTube videos automatically pause when your screen locks or the app moves to the background. This is expected behavior on iOS — both the operating system and the official YouTube embedded player enforce this to preserve battery and comply with platform policies. It is not a bug in the app.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .lineSpacing(5)
                        .padding(.top, 12)
                    Text("Running or walking with the phone in your pocket? Tap the lock icon in the video player to turn on Pocket Lock. The screen goes dark and ignores every touch while the video keeps playing. Press and hold the lock for 2 seconds to unlock.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .lineSpacing(5)
                        .padding(.top, 10)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(radius: 12)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 16)
    }

    private var dangerZoneCard: some View {
        settingsCard(icon: "trash", iconColor: Theme.destructive, title: "Danger Zone",
                     titleColor: Theme.destructive,
                     description: "Permanently delete your account and all associated data. This action cannot be undone.") {
            Button {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                showDeleteConfirm = true
            } label: {
                HStack(spacing: 8) {
                    if isDeleting {
                        ProgressView().controlSize(.small).tint(Theme.destructive)
                    } else {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                    }
                    Text("Delete Account")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(Theme.destructive)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.destructive, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)
        }
    }

    private var supportCard: some View {
        settingsCard(icon: "questionmark.circle", iconColor: Theme.accent, title: "Support", description: nil) {
            VStack(spacing: 0) {
                supportRow(icon: "questionmark.circle", label: "FAQ", route: .faq)
                Rectangle().fill(Theme.border).frame(height: 0.5)
                supportRow(icon: "checkmark.shield", label: "Privacy Policy", route: .privacy)
                Rectangle().fill(Theme.border).frame(height: 0.5)
                supportRow(icon: "doc.text", label: "Terms of Service", route: .terms)
                Rectangle().fill(Theme.border).frame(height: 0.5)
                Button {
                    if let url = URL(string: "mailto:support@travelone.ca") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    supportRowContent(icon: "bubble.left", label: "Contact Support")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func supportRow(icon: String, label: String, route: AppRoute) -> some View {
        NavigationLink(value: route) {
            supportRowContent(icon: icon, label: label)
        }
        .buttonStyle(.plain)
    }

    private func supportRowContent(icon: String, label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Theme.textSecondary)
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Save")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Theme.accentGradient)
            .clipShape(.rect(cornerRadius: 10))
        }
        .disabled(isSaving)
    }

    private var signOutButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            Task { await auth.signOut() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 14))
                Text("Sign out")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(Theme.destructive)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Theme.destructive, lineWidth: 1)
            )
        }
        .padding(.top, 28)
    }

    private func settingsCard<Content: View>(
        icon: String,
        iconColor: Color,
        title: String,
        titleColor: Color = Theme.textPrimary,
        description: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(titleColor)
            }
            if let description {
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
                    .lineSpacing(4)
                    .padding(.top, 6)
            }
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.top, 12)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(radius: 12)
        .padding(.bottom, 16)
    }

    // MARK: - Data

    private func load() async {
        guard let userId = auth.userId else {
            isLoading = false
            return
        }
        if let settings = try? await SupabaseService.shared.fetchUserSettings(userId: userId) {
            defaultEmail = settings.defaultEmail ?? ""
        }
        isLoading = false
    }

    private func save() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let email = defaultEmail.trimmingCharacters(in: .whitespaces)
        if !email.isEmpty, email.range(of: "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$", options: .regularExpression) == nil {
            toasts.show("Please enter a valid email address.", type: .error)
            return
        }
        isSaving = true
        Task {
            do {
                if !email.isEmpty, let userId = auth.userId {
                    try await SupabaseService.shared.upsertDefaultEmail(userId: userId, email: email)
                }
                toasts.show("Settings saved.")
            } catch {
                toasts.show("Failed to save settings. Please try again.", type: .error)
            }
            isSaving = false
        }
    }

    private func deleteAccount() {
        guard let userId = auth.userId else { return }
        isDeleting = true
        Task {
            let usedEdgeFunction = (try? await SupabaseService.shared.deleteAccount(userId: userId)) ?? false
            toasts.show(usedEdgeFunction ? "Your account has been deleted." : "Your account data has been deleted.")
            await auth.signOut()
            if !usedEdgeFunction,
               let url = URL(string: "mailto:support@travelone.ca?subject=Account%20Deletion%20Request") {
                await UIApplication.shared.open(url)
            }
            isDeleting = false
        }
    }
}
