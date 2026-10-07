import Foundation
import Security
import LocalAuthentication

/// Stores the user's email/password in the iOS Keychain so that Face ID / Touch ID
/// can later unlock and replay them into Supabase sign-in.
///
/// Credentials are saved only after an explicit opt-in, and only after a successful
/// manual sign-in. They are stored with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
/// (never backed up to iCloud Keychain) and wiped on sign-out / account deletion.
enum KeychainCredentialStore {
    private static let service = "app.rork.MyFeeds.credentials"
    private static let emailKey = "saved.email"
    private static let passwordKey = "saved.password"

    // MARK: - Save

    /// Persists the email and password to the Keychain.
    /// - Returns: `true` on success, `false` if either write failed.
    @discardableResult
    static func save(email: String, password: String) -> Bool {
        let emailOK = write(value: email, key: emailKey)
        let passwordOK = write(value: password, key: passwordKey)
        return emailOK && passwordOK
    }

    // MARK: - Read

    /// Returns the saved email, if any.
    static func savedEmail() -> String? {
        read(key: emailKey)
    }

    /// Returns the saved password, if any.
    static func savedPassword() -> String? {
        read(key: passwordKey)
    }

    /// Returns `(email, password)` if both are present, otherwise `nil`.
    static func savedCredentials() -> (email: String, password: String)? {
        guard let email = savedEmail(), let password = savedPassword(),
              !email.isEmpty, !password.isEmpty else { return nil }
        return (email, password)
    }

    // MARK: - Delete

    /// Removes any saved credentials (called on sign-out and account deletion).
    static func clear() {
        delete(key: emailKey)
        delete(key: passwordKey)
    }

    // MARK: - Keychain helpers

    @discardableResult
    private static func write(value: String, key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        // Remove any existing item first so upserts are clean.
        delete(key: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else { return nil }
        return value
    }

    private static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// Thin wrapper around `LAContext` for Face ID / Touch ID availability and prompts.
enum BiometricAuthService {
    /// The human-readable name for the strongest available biometric type
    /// ("Face ID" or "Touch ID"), or `nil` if biometrics are unavailable.
    static var biometryName: String? {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return nil
        }
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        case .none: return nil
        @unknown default: return nil
        }
    }

    /// `true` when the device supports biometrics AND the user has them enrolled.
    static var isAvailable: Bool { biometryName != nil }

    /// Runs a biometric authentication prompt.
    /// - Parameter reason: The localized subtitle shown under "Face ID" / "Touch ID".
    /// - Returns: `true` on success, `false` on failure or cancellation.
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = String(localized: "Use password", bundle: .appStrings)
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
