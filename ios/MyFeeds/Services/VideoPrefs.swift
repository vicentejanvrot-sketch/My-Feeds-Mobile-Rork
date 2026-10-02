import Foundation
import UIKit
import Observation

/// Video quality options matching the companion apps. "Highest available"
/// plays each video at the best quality it was uploaded in (4K when there is one).
enum VideoQuality: String, CaseIterable {
    case highest = "Highest"
    case auto = "Auto"
    case q1080 = "1080p"
    case q720 = "720p"
    case q480 = "480p"
    case q360 = "360p"
    case q240 = "240p"

    var label: String {
        switch self {
        case .highest: return "Highest available"
        case .auto: return "Auto"
        case .q1080: return "1080p HD"
        case .q720: return "720p HD"
        case .q480: return "480p"
        case .q360: return "360p"
        case .q240: return "240p"
        }
    }

    /// YouTube IFrame API quality hint.
    var youtubeValue: String {
        switch self {
        case .highest: return "highres"
        case .auto: return "default"
        case .q1080: return "hd1080"
        case .q720: return "hd720"
        case .q480: return "large"
        case .q360: return "medium"
        case .q240: return "small"
        }
    }
}

enum VideoSpeed: String, CaseIterable {
    case x1 = "1"
    case x125 = "1.25"
    case x15 = "1.5"
    case x175 = "1.75"
    case x2 = "2"

    var label: String { self == .x1 ? "Normal (1×)" : "\(rawValue)×" }
    var pillLabel: String { "\(rawValue)×" }
    var value: Double { Double(rawValue) ?? 1 }
}

/// Keys shared between local UserDefaults and iCloud NSUbiquitousKeyValueStore.
private enum PrefsKey {
    static let quality = "settings.video_quality"
    static let speed = "settings.video_speed"
    static let keepScreenOn = "settings.keep_screen_on"
    static let biometricEnabled = "settings.biometric_enabled"
}

/// Locally persisted playback preferences (quality default Highest available, speed default 2×)
/// that sync automatically across the user's devices via iCloud Key-Value Store.
@Observable
final class VideoPrefs {
    var quality: VideoQuality {
        didSet {
            let raw = quality.rawValue
            UserDefaults.standard.set(raw, forKey: PrefsKey.quality)
            NSUbiquitousKeyValueStore.default.set(raw, forKey: PrefsKey.quality)
        }
    }

    var speed: VideoSpeed {
        didSet {
            let raw = speed.rawValue
            UserDefaults.standard.set(raw, forKey: PrefsKey.speed)
            NSUbiquitousKeyValueStore.default.set(raw, forKey: PrefsKey.speed)
        }
    }

    var keepScreenOn: Bool {
        didSet {
            UserDefaults.standard.set(keepScreenOn, forKey: PrefsKey.keepScreenOn)
            NSUbiquitousKeyValueStore.default.set(keepScreenOn, forKey: PrefsKey.keepScreenOn)
        }
    }

    /// Whether the user has opted in to biometric (Face ID / Touch ID) quick sign-in.
    var biometricEnabled: Bool {
        didSet {
            UserDefaults.standard.set(biometricEnabled, forKey: PrefsKey.biometricEnabled)
            // Biometric opt-in is device-local by design — it does not sync to iCloud.
        }
    }

    /// Tracks whether the latest values came from an iCloud remote change,
    /// so observers can distinguish local edits from remote merges.
    var isApplyingRemoteChange = false

    private var ubiquityChangeObserver: NSObjectProtocol?

    init() {
        let defaults = UserDefaults.standard
        let cloud = NSUbiquitousKeyValueStore.default

        // Make sure the iCloud KVS has the latest on-disk state before reading.
        cloud.synchronize()

        quality = VideoQuality(rawValue: defaults.string(forKey: PrefsKey.quality) ?? "") ?? .highest
        speed = VideoSpeed(rawValue: defaults.string(forKey: PrefsKey.speed) ?? "") ?? .x2
        keepScreenOn = defaults.object(forKey: PrefsKey.keepScreenOn) as? Bool ?? false
        biometricEnabled = defaults.bool(forKey: PrefsKey.biometricEnabled)

        // Merge any newer iCloud values on startup.
        applyRemoteValuesIfNewer()

        // Listen for external iCloud changes (other devices).
        ubiquityChangeObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud,
            queue: .main
        ) { [weak self] notification in
            self?.handleUbiquityChange(notification)
        }
    }

    deinit {
        if let observer = ubiquityChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - iCloud sync

    /// On launch, adopt any iCloud value that is newer than (or missing from) the local store.
    private func applyRemoteValuesIfNewer() {
        let cloud = NSUbiquitousKeyValueStore.default

        if let cloudQuality = cloud.string(forKey: PrefsKey.quality),
           let parsed = VideoQuality(rawValue: cloudQuality),
           parsed != quality {
            isApplyingRemoteChange = true
            quality = parsed
            UserDefaults.standard.set(cloudQuality, forKey: PrefsKey.quality)
            isApplyingRemoteChange = false
        }

        if let cloudSpeed = cloud.string(forKey: PrefsKey.speed),
           let parsed = VideoSpeed(rawValue: cloudSpeed),
           parsed != speed {
            isApplyingRemoteChange = true
            speed = parsed
            UserDefaults.standard.set(cloudSpeed, forKey: PrefsKey.speed)
            isApplyingRemoteChange = false
        }

        // Bool defaults to false when absent; only override if the cloud explicitly has a value.
        if cloud.object(forKey: PrefsKey.keepScreenOn) != nil {
            let cloudKeepOn = cloud.bool(forKey: PrefsKey.keepScreenOn)
            if cloudKeepOn != keepScreenOn {
                isApplyingRemoteChange = true
                keepScreenOn = cloudKeepOn
                UserDefaults.standard.set(cloudKeepOn, forKey: PrefsKey.keepScreenOn)
                isApplyingRemoteChange = false
            }
        }
    }

    /// Handles an external iCloud KVS change notification by merging the changed keys.
    private func handleUbiquityChange(_ notification: Notification) {
        // The notification's userInfo may contain a list of changed keys; when missing,
        // fall back to refreshing all synced keys.
        let changedKeys: [String]
        if let userInfo = notification.userInfo,
           let keys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
            changedKeys = keys
        } else {
            changedKeys = [PrefsKey.quality, PrefsKey.speed, PrefsKey.keepScreenOn]
        }

        let cloud = NSUbiquitousKeyValueStore.default
        isApplyingRemoteChange = true
        defer { isApplyingRemoteChange = false }

        for key in changedKeys {
            switch key {
            case PrefsKey.quality:
                if let raw = cloud.string(forKey: key), let parsed = VideoQuality(rawValue: raw) {
                    quality = parsed
                    UserDefaults.standard.set(raw, forKey: key)
                }
            case PrefsKey.speed:
                if let raw = cloud.string(forKey: key), let parsed = VideoSpeed(rawValue: raw) {
                    speed = parsed
                    UserDefaults.standard.set(raw, forKey: key)
                }
            case PrefsKey.keepScreenOn:
                if cloud.object(forKey: key) != nil {
                    let value = cloud.bool(forKey: key)
                    keepScreenOn = value
                    UserDefaults.standard.set(value, forKey: key)
                }
            default:
                break
            }
        }
    }

    // MARK: - Resume positions (this phone's copy)
    // The shared copy lives in the video_progress table (see SupabaseService),
    // so web, iOS and Android resume from the same spot. updatedAt decides which
    // of the two copies is newer when a video is opened.

    func savedPosition(videoId: String) -> (time: Double, duration: Double, updatedAt: Date)? {
        guard let dict = UserDefaults.standard.dictionary(forKey: "video_position.\(videoId)"),
              let time = dict["currentTime"] as? Double,
              let duration = dict["duration"] as? Double else { return nil }
        let stamp = dict["updatedAt"] as? Double ?? 0
        return (time, duration, Date(timeIntervalSince1970: stamp))
    }

    func savePosition(videoId: String, time: Double, duration: Double, updatedAt: Date = Date()) {
        UserDefaults.standard.set(
            ["currentTime": time, "duration": duration, "updatedAt": updatedAt.timeIntervalSince1970],
            forKey: "video_position.\(videoId)"
        )
    }

    func clearPosition(videoId: String) {
        UserDefaults.standard.removeObject(forKey: "video_position.\(videoId)")
    }
}
