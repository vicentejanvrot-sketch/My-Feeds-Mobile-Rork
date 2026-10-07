import Foundation
import Supabase
import Observation

/// Global authentication state driven by Supabase auth changes.
@Observable
final class AuthStore {
    enum Status {
        case loading
        case authenticated
        case unauthenticated
    }

    var status: Status = .loading
    var userEmail: String?
    var userId: String?

    private var listenTask: Task<Void, Never>?

    func start() {
        guard listenTask == nil else { return }
        listenTask = Task { [weak self] in
            let auth = SupabaseService.shared.client.auth
            for await change in auth.authStateChanges {
                guard let self else { return }
                let session = change.session
                self.userEmail = session?.user.email
                self.userId = session?.user.id.uuidString.lowercased()
                self.status = session != nil ? .authenticated : .unauthenticated
            }
        }
    }

    func signIn(email: String, password: String) async -> String? {
        do {
            try await SupabaseService.shared.client.auth.signIn(email: email, password: password)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Backend auto-confirms accounts; if signUp returns no session, sign in immediately.
    func signUp(email: String, password: String) async -> String? {
        do {
            let response = try await SupabaseService.shared.client.auth.signUp(email: email, password: password)
            if response.session == nil {
                try await SupabaseService.shared.client.auth.signIn(email: email, password: password)
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func signOut() async {
        try? await SupabaseService.shared.client.auth.signOut()
        userEmail = nil
        userId = nil
        status = .unauthenticated
        // Wipe any saved biometric credentials on sign-out so a different user
        // cannot reuse them on the same device.
        KeychainCredentialStore.clear()
    }

    func sendPasswordReset(email: String) async -> String? {
        do {
            try await SupabaseService.shared.client.auth.resetPasswordForEmail(
                email,
                redirectTo: URL(string: "rork-app://reset-password")
            )
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func updatePassword(_ newPassword: String) async -> String? {
        do {
            try await SupabaseService.shared.client.auth.update(user: UserAttributes(password: newPassword))
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    // MARK: - Biometric helpers

    /// Called after a successful manual sign-in. When the user has opted in to
    /// biometric quick sign-in, persists the credentials to the Keychain so a
    /// future Face ID / Touch ID unlock can replay them.
    func persistCredentialsForBiometricLogin(email: String, password: String) {
        guard VideoPrefs.shared.biometricEnabled else { return }
        KeychainCredentialStore.save(email: email, password: password)
    }

    /// Returns the saved email (for pre-filling the login field), if any.
    var biometricSavedEmail: String? { KeychainCredentialStore.savedEmail() }

    /// Whether the device + the user have biometric quick sign-in ready to use.
    var isBiometricLoginAvailable: Bool {
        VideoPrefs.shared.biometricEnabled
            && BiometricAuthService.isAvailable
            && KeychainCredentialStore.savedCredentials() != nil
    }

    /// Runs Face ID / Touch ID, then replays the saved credentials into Supabase.
    /// - Returns: An error string on failure, `nil` on success.
    func signInWithBiometrics() async -> String? {
        guard let (email, password) = KeychainCredentialStore.savedCredentials() else {
            return String(localized: "No saved credentials. Please sign in with your password first.", bundle: .appStrings)
        }
        let ok = await BiometricAuthService.authenticate(
            reason: String(localized: "Unlock My Feeds with your saved login.", bundle: .appStrings)
        )
        guard ok else { return String(localized: "Biometric authentication was canceled.", bundle: .appStrings) }
        return await signIn(email: email, password: password)
    }
}

/// Shared VideoPrefs singleton used by AuthStore for biometric opt-in checks.
/// (The SwiftUI Environment instance is the same object injected at app launch.)
extension VideoPrefs {
    static let shared = VideoPrefs()
}
