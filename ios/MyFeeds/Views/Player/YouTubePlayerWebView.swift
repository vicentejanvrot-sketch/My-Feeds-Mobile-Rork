import SwiftUI
import WebKit

/// Commands sent from Swift to the embedded YouTube IFrame player.
/// Backed by the embed page's internal `movie_player` element, exposed as `window.player`.
@Observable
final class YouTubePlayerController {
    fileprivate weak var webView: WKWebView?

    var isReady = false
    var isPlaying = false
    var currentTime: Double = 0
    var duration: Double = 0
    var didEnd = false
    var loadFailed = false

    var onReady: (() -> Void)?
    var onEnded: (() -> Void)?
    var onFirstPlay: (() -> Void)?
    fileprivate var firedFirstPlay = false

    /// Last speed the app asked for. YouTube silently drops back to 1x when the
    /// app returns from the background or the embed reloads, so this value is
    /// pushed back into the page and enforced there (see bridgeScript).
    @ObservationIgnored private(set) var desiredRate: Double = 1

    private func evaluate(_ js: String) {
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    func play() { evaluate("player.playVideo();") }
    func pause() { evaluate("player.pauseVideo();") }
    func togglePlayback() {
        // Query the IFrame directly instead of relying on the asynchronously
        // mirrored Swift state, which can lag behind the actual player.
        evaluate("""
        (function() {
          if (!player || !player.getPlayerState) return;
          if (player.getPlayerState() === 1) player.pauseVideo();
          else player.playVideo();
        })();
        """)
    }
    func seek(to seconds: Double) { evaluate("player.seekTo(\(seconds), true);") }
    func skip(_ delta: Double) {
        let target = max(0, min(currentTime + delta, duration > 0 ? duration : .greatestFiniteMagnitude))
        seek(to: target)
    }
    func setRate(_ rate: Double) {
        desiredRate = rate
        evaluate("""
        window.__myfeedsDesiredRate = \(rate);
        if (window.player && player.setPlaybackRate) { player.setPlaybackRate(\(rate)); }
        """)
    }
    /// Re-sends the last requested speed (after foregrounding or a page reload).
    func reapplyRate() { setRate(desiredRate) }
    func setQuality(_ quality: String) { evaluate("player.setPlaybackQuality('\(quality)');") }
    func mute() { evaluate("player.mute();") }
    func unmute() { evaluate("player.unMute();") }
    func setVolume(_ volume: Int) { evaluate("player.setVolume(\(max(0, min(volume, 100))));") }
}

/// WKWebView hosting the YouTube embed page with a JS→Swift bridge.
struct YouTubePlayerWebView: UIViewRepresentable {
    let videoId: String
    let controller: YouTubePlayerController

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(context.coordinator, name: "bridge")

        // Bridge script: attaches to the embed page's internal player element.
        // We load the embed page directly (real network request with a Referer)
        // because YouTube now rejects players loaded from local HTML without
        // a Referer header (errors 152/153).
        let userScript = WKUserScript(
            source: Self.bridgeScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(userScript)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false

        controller.webView = webView

        var components = URLComponents(string: "https://www.youtube.com/embed/\(videoId)")!
        components.queryItems = [
            URLQueryItem(name: "playsinline", value: "1"),
            URLQueryItem(name: "controls", value: "0"),
            URLQueryItem(name: "rel", value: "0"),
            URLQueryItem(name: "modestbranding", value: "1"),
            URLQueryItem(name: "fs", value: "0"),
            URLQueryItem(name: "disablekb", value: "1"),
            URLQueryItem(name: "cc_load_policy", value: "0"),
            URLQueryItem(name: "iv_load_policy", value: "3"),
            URLQueryItem(name: "enablejsapi", value: "1"),
        ]
        var request = URLRequest(url: components.url!)
        // YouTube requires a Referer to validate embedded playback.
        request.setValue("https://myfeeds.app/", forHTTPHeaderField: "Referer")
        webView.load(request)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "bridge")
    }

    /// Injected into the YouTube embed page. Attaches to the internal
    /// `movie_player` element and mirrors events to the Swift bridge.
    private static let bridgeScript = """
    (function() {
      if (window.__myfeedsBridgeInstalled) { return; }
      window.__myfeedsBridgeInstalled = true;
      function post(msg) {
        try { window.webkit.messageHandlers.bridge.postMessage(msg); } catch (e) {}
      }
      function installCaptionLock() {
        if (document.getElementById('myfeeds-caption-lock')) { return; }
        var style = document.createElement('style');
        style.id = 'myfeeds-caption-lock';
        style.textContent = [
          '.ytp-subtitles-button { display: none !important; }',
          '.ytp-caption-window-container { display: none !important; }',
          '.caption-window { display: none !important; }',
          '.captions-text { display: none !important; }'
        ].join('\\n');
        (document.head || document.documentElement).appendChild(style);
      }
      function disableCaptions(p) {
        installCaptionLock();
        try { p.setOption('captions', 'track', {}); } catch (e) {}
        try { p.unloadModule('captions'); } catch (e) {}
      }
      document.addEventListener('keydown', function(event) {
        if ((event.key || '').toLowerCase() === 'c') {
          event.preventDefault();
          event.stopImmediatePropagation();
        }
      }, true);
      document.addEventListener('click', function(event) {
        var target = event.target;
        if (target && target.closest && target.closest('.ytp-subtitles-button')) {
          event.preventDefault();
          event.stopImmediatePropagation();
        }
      }, true);
      installCaptionLock();
      function enforceRate(p) {
        var r = window.__myfeedsDesiredRate;
        if (typeof r !== 'number') { return; }
        try {
          if (typeof p.getPlaybackRate === 'function' && Math.abs(p.getPlaybackRate() - r) > 0.01) {
            p.setPlaybackRate(r);
          }
        } catch (e) {}
        // After the app comes back from the background, iOS can reset the
        // underlying <video> to 1x while the YouTube player still reports the
        // old rate, so the check above passes. Enforce it on the element too.
        try {
          var v = document.querySelector('video');
          if (v && Math.abs(v.playbackRate - r) > 0.01) {
            v.defaultPlaybackRate = r;
            v.playbackRate = r;
          }
        } catch (e) {}
      }
      document.addEventListener('visibilitychange', function() {
        if (!document.hidden && window.player) { enforceRate(window.player); }
      });
      var attached = false;
      function attach() {
        var p = document.getElementById('movie_player');
        if (!p || typeof p.getPlayerState !== 'function') { return false; }
        attached = true;
        window.player = p;
        disableCaptions(p);
        try {
          p.addEventListener('onStateChange', function(state) {
            disableCaptions(p);
            if (state === 1 || state === 3) { enforceRate(p); }
            post({event: 'state', state: state});
          });
          p.addEventListener('onApiChange', function() {
            disableCaptions(p);
          });
          p.addEventListener('onError', function(code) {
            post({event: 'error', code: code});
          });
        } catch (e) {}
        post({event: 'ready', duration: (typeof p.getDuration === 'function' ? p.getDuration() : 0)});
        setInterval(function() {
          try {
            disableCaptions(p);
            enforceRate(p);
            post({event: 'time', time: p.getCurrentTime(), duration: p.getDuration()});
          } catch (e) {}
        }, 500);
        return true;
      }
      var tries = 0;
      var timer = setInterval(function() {
        tries++;
        if (attach()) { clearInterval(timer); return; }
        if (tries > 40) {
          clearInterval(timer);
          if (!attached) { post({event: 'error', code: -1}); }
        }
      }, 250);
    })();
    """

    final class Coordinator: NSObject, WKScriptMessageHandler {
        let controller: YouTubePlayerController

        init(controller: YouTubePlayerController) {
            self.controller = controller
            super.init()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appDidBecomeActive),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        /// Returning from the background resets YouTube's playback rate to 1x
        /// even though the selected speed pill stays highlighted. Push it back.
        @objc nonisolated func appDidBecomeActive() {
            Task { @MainActor [controller] in
                controller.reapplyRate()
            }
        }

        nonisolated func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let body = message.body as? [String: Any],
                  let event = body["event"] as? String else { return }
            let time = body["time"] as? Double
            let duration = body["duration"] as? Double
            let state = body["state"] as? Int

            Task { @MainActor [controller] in
                switch event {
                case "ready":
                    controller.isReady = true
                    if let duration { controller.duration = duration }
                    controller.onReady?()
                    controller.reapplyRate()
                case "time":
                    if let time { controller.currentTime = time }
                    if let duration, duration > 0 { controller.duration = duration }
                case "state":
                    guard let state else { return }
                    switch state {
                    case 1:
                        controller.isPlaying = true
                        if !controller.firedFirstPlay {
                            controller.firedFirstPlay = true
                            controller.onFirstPlay?()
                        }
                    case 2, 5, -1:
                        controller.isPlaying = false
                    case 0:
                        controller.isPlaying = false
                        if !controller.didEnd {
                            controller.didEnd = true
                            controller.onEnded?()
                        }
                    default:
                        break
                    }
                case "error":
                    controller.loadFailed = true
                default:
                    break
                }
            }
        }
    }
}
