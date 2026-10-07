import Foundation

/// The app's display language, kept on this device only.
///
/// "Automatic" means no override, so iOS uses the device language (Portuguese
/// falls back to pt-BR, everything else to English). Picking English or
/// Português (Brasil) writes the per-app `AppleLanguages` override, the same
/// one the app's page in the Settings app writes. iOS reads it when the app
/// starts, so the new language shows after My Feeds is reopened.
///
/// The choice is also copied to the app group, so the Share to My Feeds
/// extension follows it (see ShareViewController).
enum AppLanguage {
    enum Choice: String, CaseIterable {
        case automatic
        case english = "en"
        case portugueseBrazil = "pt-BR"
    }

    /// Key in the app group defaults the share extension reads.
    static let sharedKey = "appLanguage"
    private static let appGroup = "group.app.rork.je0yu8oeyjzcpim4k10q0"

    /// The language the running app started with. Read once at launch
    /// (MyFeedsApp.init), so Settings can tell when a reopen is needed.
    static let launchChoice: Choice = choice

    /// The current override, if any (also set by the Settings app's Language row).
    static var choice: Choice {
        let domain = Bundle.main.bundleIdentifier.flatMap { UserDefaults.standard.persistentDomain(forName: $0) }
        guard let languages = domain?["AppleLanguages"] as? [String], let first = languages.first else {
            return .automatic
        }
        return first.lowercased().hasPrefix("pt") ? .portugueseBrazil : .english
    }

    static func set(_ newChoice: Choice) {
        switch newChoice {
        case .automatic:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .english, .portugueseBrazil:
            UserDefaults.standard.set([newChoice.rawValue], forKey: "AppleLanguages")
        }
        syncShareExtension()
    }

    /// Copies the current choice to the app group for the share extension.
    static func syncShareExtension() {
        guard let shared = UserDefaults(suiteName: appGroup) else { return }
        let current = choice
        if current == .automatic {
            shared.removeObject(forKey: sharedKey)
        } else {
            shared.set(current.rawValue, forKey: sharedKey)
        }
    }
}
