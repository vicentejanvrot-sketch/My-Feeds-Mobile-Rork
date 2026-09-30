import Foundation
import Supabase

/// When the onboarding wizard opens by itself. It opens once per app launch
/// until the user ticks "Don't show this again". That choice is saved on the
/// user's auth metadata ("hide_onboarding"), the same key the web and Expo
/// apps use, so it follows the user to every device.
enum OnboardingPrefs {
    static let hideKey = "hide_onboarding"

    private static var shownThisLaunch = false

    static func markShown() {
        shownThisLaunch = true
    }

    /// The choice as the app last saw it, for the checkbox's first state.
    static var isHidden: Bool {
        guard let user = SupabaseService.shared.client.auth.currentUser else { return false }
        return hidden(in: user.userMetadata)
    }

    /// True when the wizard should open by itself on the Dashboard.
    static func shouldAutoOpen() async -> Bool {
        if shownThisLaunch { return false }
        // Read the user fresh, in case they ticked the box on another device.
        guard let user = try? await SupabaseService.shared.client.auth.user() else { return false }
        return !hidden(in: user.userMetadata) && !shownThisLaunch
    }

    /// Saves "Don't show this again". Returns an error message, or nil when saved.
    static func setHidden(_ hidden: Bool) async -> String? {
        do {
            try await SupabaseService.shared.client.auth.update(
                user: UserAttributes(data: [hideKey: .bool(hidden)])
            )
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private static func hidden(in metadata: [String: AnyJSON]) -> Bool {
        if case .bool(true)? = metadata[hideKey] { return true }
        return false
    }
}
