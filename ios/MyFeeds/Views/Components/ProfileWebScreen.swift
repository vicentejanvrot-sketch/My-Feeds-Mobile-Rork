import SwiftUI
import WebKit

/// A private account's profile (Instagram, TikTok, X, Facebook), opened inside
/// My Feeds. My Feeds can't read a private account's posts (it doesn't sign in
/// as the user), so this shows the platform's own page. The user signs in there
/// once; the sign-in stays on this phone (the web view's own cookies) and never
/// reaches My Feeds' servers.
struct ProfileWebScreen: View {
    let url: URL
    let name: String
    let platformLabel: String
    let onClose: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var model = ProfileWebModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                circleButton("xmark", label: "Close", action: onClose)
                if model.canGoBack {
                    circleButton("chevron.left", label: "Back") { model.webView?.goBack() }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(name.isEmpty ? "Profile" : name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    if !platformLabel.isEmpty {
                        Text("\(platformLabel) · signed in on this phone only")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textMuted)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                circleButton("arrow.clockwise", label: "Reload") { model.webView?.reload() }
                circleButton("arrow.up.right.square", label: "Open in \(platformLabel.isEmpty ? "the app" : platformLabel)") {
                    openURL(url)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 0.5) }

            ZStack(alignment: .top) {
                ProfileWebView(url: url, model: model)
                if model.isLoading {
                    ProgressView().tint(Theme.accent).padding(.top, 16)
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private func circleButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 36, height: 36)
                .background(Theme.input, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// What the header needs from the web view.
@Observable
final class ProfileWebModel {
    var canGoBack = false
    var isLoading = true
    @ObservationIgnored weak var webView: WKWebView?
}

private struct ProfileWebView: UIViewRepresentable {
    let url: URL
    let model: ProfileWebModel

    // A normal iPhone Safari, so the platform shows its full mobile site and
    // lets the user sign in.
    private static let userAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // The default store keeps the sign-in between visits.
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = Self.userAgent
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = UIColor(Theme.background)
        model.webView = webView
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let model: ProfileWebModel
        init(model: ProfileWebModel) { self.model = model }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            model.isLoading = true
            model.canGoBack = webView.canGoBack
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            model.isLoading = false
            model.canGoBack = webView.canGoBack
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            model.isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            model.isLoading = false
        }

        // Links the platform would hand to its own app stay in here.
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            let scheme = navigationAction.request.url?.scheme?.lowercased() ?? ""
            if navigationAction.targetFrame == nil, scheme == "http" || scheme == "https" {
                // A link meant for a new window opens here instead.
                webView.load(navigationAction.request)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(["http", "https", "about", "blob", "data"].contains(scheme) ? .allow : .cancel)
        }
    }
}

/// A private account to open in ProfileWebScreen.
struct ProfileTarget: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let name: String
    let platformLabel: String
}

extension View {
    /// Shows a private account's profile inside the app while `target` is set.
    func profileViewer(_ target: Binding<ProfileTarget?>) -> some View {
        fullScreenCover(item: target) { t in
            ProfileWebScreen(url: t.url, name: t.name, platformLabel: t.platformLabel) { target.wrappedValue = nil }
        }
    }
}
