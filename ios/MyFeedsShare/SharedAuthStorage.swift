import Foundation
import Supabase

/// Where the signed-in session is kept, so the "Share to My Feeds" extension
/// (ios/MyFeedsShare) can use it too: the keychain, in the app group both
/// targets belong to. Whichever one refreshes the session writes the new one
/// here and the other reads it, so they never sign each other out.
///
/// Sessions saved before this existed are in the app's own keychain; they are
/// read from there until the next save moves them into the shared group. If
/// the app group isn't available (a build without the entitlement), the app
/// keeps working from its own keychain as before; only sharing is affected.
/// Keep in sync with ios/MyFeeds/Services/SharedAuthStorage.swift.
nonisolated struct SharedAuthStorage: AuthLocalStorage {
    static let appGroup = "group.app.rork.je0yu8oeyjzcpim4k10q0"

    private let shared = KeychainLocalStorage(service: "supabase.gotrue.swift", accessGroup: SharedAuthStorage.appGroup)
    private let own = KeychainLocalStorage(service: "supabase.gotrue.swift", accessGroup: nil)

    func store(key: String, value: Data) throws {
        do {
            // The shared copy is the one read from now on. The old copy in the
            // app's own keychain is left alone: deleting it without a group
            // would delete the shared copy too (a keychain delete with no
            // group matches every group), which signed the app out of its data.
            try shared.store(key: key, value: value)
        } catch {
            try own.store(key: key, value: value)
        }
    }

    func retrieve(key: String) throws -> Data? {
        if let value = try? shared.retrieve(key: key) { return value }
        return try own.retrieve(key: key)
    }

    func remove(key: String) throws {
        try? shared.remove(key: key)
        try? own.remove(key: key)
    }
}
