import Foundation
import Observation

/// The app's display language, kept on this device only.
///
/// "Automatic" means no override, so iOS uses the device language (Portuguese
/// falls back to pt-BR, everything else to English). Picking English or
/// Português (Brasil) writes the per-app `AppleLanguages` override, the same
/// one the app's page in the Settings app writes, so the next launch starts
/// in that language.
///
/// The running app switches right away too: Bundle.main is pointed at the
/// chosen language's strings (see LanguageBundle) and ContentView rebuilds
/// the screens when `live.code` changes, so no reopen is needed.
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

    /// The language the screens are showing right now ("en" or "pt-BR").
    /// ContentView watches it and rebuilds the tabs when it changes.
    static let live = LiveLanguage()

    /// The current override, if any (also set by the Settings app's Language row).
    static var choice: Choice {
        let domain = Bundle.main.bundleIdentifier.flatMap { UserDefaults.standard.persistentDomain(forName: $0) }
        guard let languages = domain?["AppleLanguages"] as? [String], let first = languages.first else {
            return .automatic
        }
        return first.lowercased().hasPrefix("pt") ? .portugueseBrazil : .english
    }

    /// Called once at launch (MyFeedsApp.init): points Bundle.main at the
    /// chosen language's strings and passes the choice to the share extension.
    static func start() {
        LanguageBundle.install()
        apply(choice)
        syncShareExtension()
    }

    static func set(_ newChoice: Choice) {
        switch newChoice {
        case .automatic:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .english, .portugueseBrazil:
            UserDefaults.standard.set([newChoice.rawValue], forKey: "AppleLanguages")
        }
        syncShareExtension()
        apply(newChoice)
    }

    /// Switches the running app's strings to the given choice.
    private static func apply(_ choice: Choice) {
        let code = resolvedCode(for: choice)
        LanguageBundle.select(code)
        if live.code != code {
            live.code = code
        }
    }

    private static func resolvedCode(for choice: Choice) -> String {
        switch choice {
        case .automatic: return deviceCode()
        case .english, .portugueseBrazil: return choice.rawValue
        }
    }

    /// The device's own language, ignoring this app's override.
    private static func deviceCode() -> String {
        let global = CFPreferencesCopyValue(
            "AppleLanguages" as CFString,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        ) as? [String]
        let first = global?.first ?? Locale.preferredLanguages.first ?? "en"
        return first.lowercased().hasPrefix("pt") ? "pt-BR" : "en"
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

/// The language code the screens are using, observed by ContentView.
@Observable
final class LiveLanguage {
    var code: String = "en"

    var locale: Locale { Locale(identifier: code) }
}

/// Bundle.main is switched to this class at launch so every lookup
/// (Text("..."), String(localized:), NSLocalizedString) reads the strings of
/// the language picked in Settings instead of the one iOS chose at launch.
nonisolated final class LanguageBundle: Bundle, @unchecked Sendable {
    nonisolated(unsafe) private static var languageBundle: Bundle?
    nonisolated(unsafe) private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true
        object_setClass(Bundle.main, LanguageBundle.self)
    }

    /// Loads the .lproj folder for "en" or "pt-BR". If it can't be found,
    /// lookups fall back to iOS's own choice.
    static func select(_ code: String) {
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            languageBundle = bundle
        } else {
            languageBundle = nil
        }
    }

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let bundle = Self.languageBundle {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}
