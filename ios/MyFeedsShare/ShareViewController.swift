import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// "Share to My Feeds": the extension iOS shows when the user picks My Feeds
/// in another app's share sheet. It reads the shared link or text and shows
/// the Add to My Feeds card over that app, so the user never leaves it.
final class ShareViewController: UIViewController {
    private let model = ShareModel()

    // Full screen and see-through, so only the card covers the app the user
    // shared from (not the grey sheet iOS puts behind an extension by default).
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        Self.applyAppLanguage()
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        modalPresentationStyle = .overFullScreen
    }

    required init?(coder: NSCoder) {
        Self.applyAppLanguage()
        super.init(coder: coder)
        modalPresentationStyle = .overFullScreen
    }

    /// The language picked in the app's Settings ("en" / "pt-BR"), shared
    /// through the app group; nil means Automatic (the device language).
    private static var appLanguage: String? {
        UserDefaults(suiteName: SharedAuthStorage.appGroup)?.string(forKey: "appLanguage")
    }

    /// Uses the app's language choice in the extension too: the same per-app
    /// override the app uses, set before any text is looked up.
    private static func applyAppLanguage() {
        if let language = appLanguage {
            UserDefaults.standard.set([language], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        model.onClose = { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }

        let locale = Self.appLanguage.map { Locale(identifier: $0) } ?? Locale.autoupdatingCurrent
        let host = UIHostingController(rootView: ShareCardView(model: model).environment(\.locale, locale))
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        Task { @MainActor in
            let shared = await Self.sharedText(from: items)
            model.start(shared: shared)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // If iOS still presents a sheet instead of the see-through full screen,
        // the card fills that sheet so there's no empty white block above it.
        let screen = view.window?.windowScene?.screen.bounds ?? UIScreen.main.bounds
        let frame = view.convert(view.bounds, to: nil)
        model.inSheet = frame.minY > 1 || frame.height < screen.height - 1
    }

    /// Links first (the server reads the first link it finds), then any text.
    /// Apps share in different shapes: YouTube, TikTok, Facebook and LinkedIn
    /// add a preview image or video next to the link, and some send the link
    /// as text or data. Anything that isn't a link or text is ignored.
    @MainActor
    private static func sharedText(from items: [NSExtensionItem]) async -> String {
        var links: [String] = []
        var texts: [String] = []
        func string(from loaded: Any?) -> String? {
            switch loaded {
            case let url as URL: return url.absoluteString
            case let text as String: return text
            case let attributed as NSAttributedString: return attributed.string
            case let data as Data: return String(data: data, encoding: .utf8)
            default: return nil
            }
        }
        for item in items {
            if let text = item.attributedContentText?.string, !text.isEmpty { texts.append(text) }
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    let loaded = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier)
                    if let text = string(from: loaded), !text.isEmpty { links.append(text) }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                    let loaded = try? await provider.loadItem(forTypeIdentifier: UTType.text.identifier)
                    if let text = string(from: loaded), !text.isEmpty { texts.append(text) }
                }
            }
        }
        return (links + texts).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
