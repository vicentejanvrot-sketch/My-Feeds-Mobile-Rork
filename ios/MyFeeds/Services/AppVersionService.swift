import Foundation
import Supabase
import UIKit

/// Which app version this iPhone runs, saved to the app_installs table when the
/// app opens (one row per phone), and whether a newer one is out
/// (app_releases: latest_version shows "Update available", min_version blocks
/// older versions until updated). The App Store itself is asked too, so a new
/// release shows without touching the table. Same as the Expo app's
/// lib/app-version.ts.
enum AppVersionService {
    static let appStoreId = "6778948617"
    private static let deviceKey = "app.deviceId"

    /// The version people see in the App Store, e.g. "1.0.11".
    static var appVersion: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    static var buildNumber: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }

    /// -1 when a is older than b, 0 when equal, 1 when newer. "1.0.10" is newer than "1.0.9".
    static func compare(_ a: String, _ b: String) -> Int {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x < y ? -1 : 1 }
        }
        return 0
    }

    /// A random id kept on this phone, so each phone is one row.
    private static var deviceId: String {
        if let saved = UserDefaults.standard.string(forKey: deviceKey) { return saved }
        let id = UUID().uuidString.lowercased()
        UserDefaults.standard.set(id, forKey: deviceKey)
        return id
    }

    /// Saves this phone's app version for the signed-in user. Best effort.
    static func reportInstall(userId: String) async {
        guard let version = appVersion else { return }
        let row = AppInstallRow(
            userId: userId,
            deviceId: deviceId,
            platform: "ios",
            appVersion: version,
            build: buildNumber,
            osVersion: "iOS \(UIDevice.current.systemVersion)",
            deviceModel: UIDevice.current.model,
            lastSeenAt: ISO8601DateFormatter().string(from: Date())
        )
        _ = try? await SupabaseService.shared.client.schema("public")
            .from("app_installs")
            .upsert(row, onConflict: "user_id,device_id")
            .execute()
    }

    struct UpdateInfo: Equatable {
        let latestVersion: String
        let storeURL: URL
        /// This version is below the minimum: the app can't be used until updated.
        let required: Bool
    }

    /// A newer version than this one, or nil when the app is up to date.
    static func checkForUpdate() async -> UpdateInfo? {
        guard let current = appVersion else { return nil }
        var latest: String?
        var minimum: String?
        var storeURL: URL?

        let rows: [AppReleaseRow]? = try? await SupabaseService.shared.client.schema("public")
            .from("app_releases")
            .select("latest_version, min_version, store_url")
            .eq("platform", value: "ios")
            .limit(1)
            .execute()
            .value
        if let release = rows?.first {
            latest = release.latestVersion
            minimum = release.minVersion
            storeURL = release.storeUrl.flatMap(URL.init(string:))
        }

        // The App Store's own latest version.
        if let url = URL(string: "https://itunes.apple.com/lookup?id=\(appStoreId)&t=\(Int(Date().timeIntervalSince1970))"),
           let response = try? await URLSession.shared.data(from: url),
           let json = try? JSONSerialization.jsonObject(with: response.0) as? [String: Any],
           let store = (json["results"] as? [[String: Any]])?.first {
            if let version = store["version"] as? String, latest == nil || compare(version, latest!) > 0 {
                latest = version
            }
            if storeURL == nil, let raw = store["trackViewUrl"] as? String { storeURL = URL(string: raw) }
        }

        guard let latest, let storeURL else { return nil }
        let required = minimum.map { compare(current, $0) < 0 } ?? false
        if !required && compare(current, latest) >= 0 { return nil }
        return UpdateInfo(latestVersion: latest, storeURL: storeURL, required: required)
    }
}

/// One row of app_installs (see AppVersionService.reportInstall).
nonisolated private struct AppInstallRow: Encodable, Sendable {
    let userId: String
    let deviceId: String
    let platform: String
    let appVersion: String
    let build: String?
    let osVersion: String
    let deviceModel: String
    let lastSeenAt: String
}

/// One row of app_releases (see AppVersionService.checkForUpdate).
nonisolated private struct AppReleaseRow: Decodable, Sendable {
    let latestVersion: String?
    let minVersion: String?
    let storeUrl: String?
}
