import AuthenticationServices
import Foundation
import Observation
import Supabase
import UIKit

/// GitHub and Reddit accounts the user connected, through the account-connect
/// edge function, so adding a GitHub or Reddit account on People also follows
/// it there. The sign-in opens in a secure browser sheet; GitHub or Reddit
/// sends it to the web app's /connect-callback page, which hands the code back
/// through myfeeds://connect-auth. The tokens stay on the server. Same as
/// src/hooks/useConnections.ts (web) and expo/lib/useConnections.ts.
@Observable
final class AccountConnections {
    static let shared = AccountConnections()

    nonisolated enum Provider: String, CaseIterable, Sendable {
        case github, reddit

        var label: String { self == .github ? "GitHub" : "Reddit" }
        var platform: SourcePlatform { self == .github ? .github : .reddit }

        init?(platform: SourcePlatform) {
            switch platform {
            case .github: self = .github
            case .reddit: self = .reddit
            default: return nil
            }
        }
    }

    /// Account name per connected provider ("octocat", "u/name"); nil value = connected, name unknown.
    private(set) var connected: [Provider: String?] = [:]
    private(set) var loaded = false
    private(set) var busy: Provider?

    private static let returnURL = "myfeeds://connect-auth"
    private static let callbackScheme = "myfeeds"

    @ObservationIgnored private var session: ASWebAuthenticationSession?
    @ObservationIgnored private let presenter = ConnectPresenter()

    private init() {}

    func isConnected(_ provider: Provider) -> Bool { connected.keys.contains(provider) }

    func load() async {
        do {
            let reply: ListResponse = try await invoke(Payload(action: "list"))
            var map: [Provider: String?] = [:]
            for c in reply.connections ?? [] {
                if let p = Provider(rawValue: c.provider) { map.updateValue(c.accountName, forKey: p) }
            }
            connected = map
            loaded = true
        } catch {
            // Settings shows "Not connected"; People adds without following.
        }
    }

    /// Opens the sign-in and finishes the connection. Returns the account
    /// name, or throws AccountConnectionError.cancelled when the sheet is closed.
    @discardableResult
    func connect(_ provider: Provider) async throws -> String? {
        guard busy == nil else { return nil }
        busy = provider
        defer { busy = nil }

        let start: StartResponse = try await invoke(Payload(action: "start", provider: provider.rawValue, appReturnUrl: Self.returnURL))
        guard let raw = start.authUrl, let authURL = URL(string: raw) else {
            throw AccountConnectionError.message(start.error ?? String(localized: "Couldn't open \(provider.label).", bundle: .appStrings))
        }

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: Self.callbackScheme) { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else if let authError = error as? ASWebAuthenticationSessionError, authError.code == .canceledLogin {
                    continuation.resume(throwing: AccountConnectionError.cancelled)
                } else {
                    continuation.resume(throwing: error ?? AccountConnectionError.message(String(localized: "\(provider.label) sign-in failed.", bundle: .appStrings)))
                }
            }
            session.presentationContextProvider = presenter
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            if !session.start() {
                continuation.resume(throwing: AccountConnectionError.message(String(localized: "Couldn't open \(provider.label) sign-in.", bundle: .appStrings)))
            }
        }
        session = nil

        let query = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let error = query.first(where: { $0.name == "error" })?.value {
            if error == "access_denied" { throw AccountConnectionError.cancelled }
            throw AccountConnectionError.message(String(localized: "\(provider.label) sign-in failed (\(error)).", bundle: .appStrings))
        }
        guard let code = query.first(where: { $0.name == "code" })?.value, !code.isEmpty,
              let state = query.first(where: { $0.name == "state" })?.value, !state.isEmpty else {
            throw AccountConnectionError.message(String(localized: "\(provider.label) didn't finish the sign-in. Try again.", bundle: .appStrings))
        }

        let done: FinishResponse = try await invoke(Payload(action: "finish", code: code, state: state))
        if let error = done.error { throw AccountConnectionError.message(error) }
        connected.updateValue(done.accountName, forKey: provider)
        return done.accountName
    }

    func disconnect(_ provider: Provider) async throws {
        busy = provider
        defer { busy = nil }
        let reply: OkResponse = try await invoke(Payload(action: "disconnect", provider: provider.rawValue))
        if let error = reply.error { throw AccountConnectionError.message(error) }
        connected.removeValue(forKey: provider)
    }

    /// Follows the GitHub or Reddit account at url with the user's connected
    /// account. Returns true when they already followed it.
    func follow(_ provider: Provider, url: String) async throws -> Bool {
        let reply: OkResponse = try await invoke(Payload(action: "follow", provider: provider.rawValue, url: url))
        if let error = reply.error { throw AccountConnectionError.message(error) }
        return reply.already == true
    }

    private func invoke<Response: Decodable>(_ body: Payload) async throws -> Response {
        do {
            return try await SupabaseService.shared.client.functions.invoke(
                "account-connect",
                options: FunctionInvokeOptions(body: body),
                decoder: JSONDecoder()
            )
        } catch FunctionsError.httpError(_, let data) {
            let message = (try? JSONDecoder().decode(OkResponse.self, from: data))?.error
            throw AccountConnectionError.message(message ?? String(localized: "Something went wrong. Try again.", bundle: .appStrings))
        }
    }
}

nonisolated enum AccountConnectionError: LocalizedError {
    case cancelled
    case message(String)

    var errorDescription: String? {
        switch self {
        case .cancelled: return String(localized: "The connection was cancelled.", bundle: .appStrings)
        case .message(let text): return text
        }
    }
}

/// Shows the sign-in sheet over the app's current window.
private final class ConnectPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        return windows.first(where: \.isKeyWindow) ?? windows.first ?? ASPresentationAnchor()
    }
}

// MARK: - Payloads (camelCase, as the function expects; nil fields are left out)

private nonisolated struct Payload: Encodable, Sendable {
    let action: String
    var provider: String? = nil
    var appReturnUrl: String? = nil
    var code: String? = nil
    var state: String? = nil
    var url: String? = nil
}

private nonisolated struct ListResponse: Decodable, Sendable {
    var connections: [Item]?
    var error: String?

    nonisolated struct Item: Decodable, Sendable {
        var provider: String
        var accountName: String?
    }
}

private nonisolated struct StartResponse: Decodable, Sendable { var authUrl: String?; var error: String? }
private nonisolated struct FinishResponse: Decodable, Sendable { var provider: String?; var accountName: String?; var error: String? }
private nonisolated struct OkResponse: Decodable, Sendable { var ok: Bool?; var already: Bool?; var error: String? }
