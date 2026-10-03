import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// "Share to My Feeds": the extension iOS shows when the user picks My Feeds
/// in another app's share sheet. It reads the shared link or text and shows
/// the Add to My Feeds card over that app, so the user never leaves it.
final class ShareViewController: UIViewController {
    private let model = ShareModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        model.onClose = { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }

        let host = UIHostingController(rootView: ShareCardView(model: model))
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

    /// Links first (the server reads the first link it finds), then any text.
    @MainActor
    private static func sharedText(from items: [NSExtensionItem]) async -> String {
        var links: [String] = []
        var texts: [String] = []
        for item in items {
            if let text = item.attributedContentText?.string, !text.isEmpty { texts.append(text) }
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let loaded = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) {
                    if let url = loaded as? URL { links.append(url.absoluteString) }
                    else if let text = loaded as? String { links.append(text) }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                          let loaded = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) {
                    if let text = loaded as? String { texts.append(text) }
                }
            }
        }
        return (links + texts).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
