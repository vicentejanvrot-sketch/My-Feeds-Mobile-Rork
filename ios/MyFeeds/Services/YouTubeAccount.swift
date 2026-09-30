import AuthenticationServices
import Foundation
import Observation
import Security
import Supabase
import UIKit

/// The user's YouTube account on iPhone, connected the same way as the Android
/// app: Google sign-in opens in a secure browser sheet, Google sends it to the
/// web app's /youtube-auth-callback page, which hands the code back through
/// myfeeds://youtube-auth, and the youtube-auth-callback edge function swaps it
/// for tokens. The tokens stay on this phone, in the Keychain.
///
/// Used by "Add to YouTube Music" (the "My Feeds" playlist) and shown in Settings.
@Observable
final class YouTubeAccount {
    static let shared = YouTubeAccount()

    private(set) var channelName: String?
    private(set) var isConnected = false
    private(set) var isConnecting = false

    private static let returnURL = "myfeeds://youtube-auth"
    private static let callbackScheme = "myfeeds"
    /// The single redirect URI registered on the Google OAuth client.
    private static let redirectURI = "https://webapp.myfeeds.ca/youtube-auth-callback"
    private static let keychainService = "MyFeeds.YouTube"
    private static let keychainAccount = "tokens"

    @ObservationIgnored private var session: ASWebAuthenticationSession?
    @ObservationIgnored private let presenter = AuthPresenter()

    private init() {
        if let stored = Self.readTokens() {
            channelName = stored.channelName
            isConnected = true
        }
    }

    // MARK: - Connect / disconnect

    func connect() async throws {
        guard !isConnecting else { return }
        isConnecting = true
        defer { isConnecting = false }

        let start: AuthStartResponse = try await invoke("youtube-auth", body: AuthStartPayload(appReturnUrl: Self.returnURL))
        guard let raw = start.authUrl, let authURL = URL(string: raw) else {
            throw YouTubeAccountError.message(start.error ?? "Couldn't start YouTube sign-in.")
        }

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: Self.callbackScheme) { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else if let authError = error as? ASWebAuthenticationSessionError, authError.code == .canceledLogin {
                    continuation.resume(throwing: YouTubeAccountError.cancelled)
                } else {
                    continuation.resume(throwing: error ?? YouTubeAccountError.message("YouTube sign-in failed."))
                }
            }
            session.presentationContextProvider = presenter
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            if !session.start() {
                continuation.resume(throwing: YouTubeAccountError.message("Couldn't open YouTube sign-in."))
            }
        }
        session = nil

        let query = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let error = query.first(where: { $0.name == "error" })?.value {
            throw YouTubeAccountError.message(error == "access_denied" ? "YouTube access was denied." : "YouTube sign-in failed (\(error)).")
        }
        guard let code = query.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw YouTubeAccountError.message("YouTube didn't send a sign-in code. Try again.")
        }

        let tokens: AuthCallbackResponse = try await invoke(
            "youtube-auth-callback",
            body: AuthCallbackPayload(code: code, redirectUri: Self.redirectURI)
        )
        guard let accessToken = tokens.accessToken else {
            throw YouTubeAccountError.message(tokens.error ?? "Couldn't finish connecting YouTube.")
        }
        let name = tokens.channel?.name ?? tokens.email
        Self.writeTokens(StoredTokens(
            accessToken: accessToken,
            refreshToken: tokens.refreshToken,
            expiresAt: tokens.expiresIn.map { Date().addingTimeInterval(TimeInterval($0)) },
            channelName: name
        ))
        channelName = name
        isConnected = true
    }

    func disconnect() {
        Self.deleteTokens()
        channelName = nil
        isConnected = false
    }

    // MARK: - Add to YouTube Music

    /// Puts the songs in the user's "My Feeds" playlist (made private the first
    /// time); songs already there are skipped. Returns how many were added.
    func addToMusicPlaylist(videoIds: [String]) async throws -> Int {
        let token = try await accessToken()
        let result: AddTracksResponse = try await invoke(
            "youtube-api",
            body: AddTracksPayload(action: "add_tracks_to_music_playlist", accessToken: token, videoIds: videoIds)
        )
        if let error = result.error { throw YouTubeAccountError.message(error) }
        return result.added ?? 0
    }

    // MARK: - Tokens

    /// A valid access token, refreshed when it's about to expire.
    private func accessToken() async throws -> String {
        guard var stored = Self.readTokens() else {
            disconnect()
            throw YouTubeAccountError.notConnected
        }
        if let expiresAt = stored.expiresAt, expiresAt > Date().addingTimeInterval(5 * 60) {
            return stored.accessToken
        }
        guard let refreshToken = stored.refreshToken else {
            disconnect()
            throw YouTubeAccountError.message("Your YouTube sign-in expired. Connect YouTube again.")
        }
        let refreshed: RefreshResponse = try await invoke("youtube-api", body: RefreshPayload(action: "refresh", refreshToken: refreshToken))
        guard let token = refreshed.accessToken else {
            disconnect()
            throw YouTubeAccountError.message("Your YouTube sign-in expired. Connect YouTube again.")
        }
        stored.accessToken = token
        stored.expiresAt = Date().addingTimeInterval(TimeInterval(refreshed.expiresIn ?? 3600))
        Self.writeTokens(stored)
        return token
    }

    private func invoke<Body: Encodable, Response: Decodable>(_ function: String, body: Body) async throws -> Response {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try await SupabaseService.shared.client.functions.invoke(
                function,
                options: FunctionInvokeOptions(body: body),
                decoder: decoder
            )
        } catch FunctionsError.httpError(_, let data) {
            let message = (try? decoder.decode(ErrorResponse.self, from: data))?.error
            throw YouTubeAccountError.message(message ?? "YouTube request failed. Try again.")
        }
    }

    private static func readTokens() -> StoredTokens? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(StoredTokens.self, from: data)
    }

    private static func writeTokens(_ tokens: StoredTokens) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        deleteTokens()
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data,
        ]
        SecItemAdd(item as CFDictionary, nil)
    }

    private static func deleteTokens() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum YouTubeAccountError: LocalizedError {
    case cancelled
    case notConnected
    case message(String)

    var errorDescription: String? {
        switch self {
        case .cancelled: return "YouTube sign-in was cancelled."
        case .notConnected: return "Connect YouTube first."
        case .message(let text): return text
        }
    }
}

/// Shows the sign-in sheet over the app's current window.
private final class AuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        return windows.first(where: \.isKeyWindow) ?? windows.first ?? ASPresentationAnchor()
    }
}

// MARK: - Payloads (sent as-is, camelCase like the web and Android apps)

private nonisolated struct StoredTokens: Codable, Sendable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date?
    var channelName: String?
}

private nonisolated struct AuthStartPayload: Encodable, Sendable { let appReturnUrl: String }
private nonisolated struct AuthStartResponse: Decodable, Sendable { var authUrl: String?; var error: String? }

private nonisolated struct AuthCallbackPayload: Encodable, Sendable { let code: String; let redirectUri: String }
private nonisolated struct AuthCallbackResponse: Decodable, Sendable {
    var accessToken: String?
    var refreshToken: String?
    var expiresIn: Int?
    var email: String?
    var channel: Channel?
    var error: String?

    nonisolated struct Channel: Decodable, Sendable { var name: String? }
}

private nonisolated struct RefreshPayload: Encodable, Sendable { let action: String; let refreshToken: String }
private nonisolated struct RefreshResponse: Decodable, Sendable { var accessToken: String?; var expiresIn: Int? }

private nonisolated struct AddTracksPayload: Encodable, Sendable { let action: String; let accessToken: String; let videoIds: [String] }
private nonisolated struct AddTracksResponse: Decodable, Sendable { var added: Int?; var alreadyThere: Int?; var error: String? }

private nonisolated struct ErrorResponse: Decodable, Sendable { var error: String? }
