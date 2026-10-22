import SwiftUI
import WebKit

@MainActor
final class Playback: ObservableObject {
    @Published var duration: Double = 0
    @Published var position: Double = 0
    @Published var part = 0
    @Published var completed = false
    @Published var ready = false
    @Published var error: String?
    weak var webView: WKWebView?
    var timeline: PartTimeline { PartTimeline(duration: duration) }
    func go(to index: Int) {
        guard timeline.count > 0 else { return }
        let index = min(max(index, 0), timeline.count - 1)
        webView?.evaluateJavaScript("choosePart(\(index))")
    }
    func pause() { webView?.evaluateJavaScript("if(player && player.pauseVideo) player.pauseVideo()") }
}

struct YouTubePlayer: UIViewRepresentable {
    let video: SavedVideo
    @ObservedObject var playback: Playback
    func makeCoordinator() -> Coordinator { Coordinator(playback) }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.userContentController.add(context.coordinator, name: "player")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        playback.webView = webView
        let origin = "https://\((Bundle.main.bundleIdentifier ?? "com.shengy.parts").lowercased())"
        let values: [String: Any] = ["id": video.id, "position": video.position, "origin": origin]
        if let path = Bundle.main.url(forResource: "player", withExtension: "html"),
           let template = try? String(contentsOf: path, encoding: .utf8),
           let data = try? JSONSerialization.data(withJSONObject: values),
           let json = String(data: data, encoding: .utf8) {
            webView.loadHTMLString(template.replacingOccurrences(of: "__CONFIG__", with: json), baseURL: URL(string: origin))
        } else { playback.error = "The player could not be loaded. Please reopen the app." }
        return webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.evaluateJavaScript("if(player && player.pauseVideo) player.pauseVideo()")
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "player")
        uiView.navigationDelegate = nil
    }
    @MainActor final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let playback: Playback
        init(_ playback: Playback) { self.playback = playback }
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame, let data = message.body as? [String: Any], let type = data["type"] as? String else { return }
            switch type {
            case "ready": playback.ready = true
            case "progress":
                guard let duration = data["duration"] as? Double, duration.isFinite, duration > 0,
                      let time = data["time"] as? Double, time.isFinite else { return }
                playback.duration = duration
                playback.position = max(0, min(time, duration))
                playback.part = data["part"] as? Int ?? 0
                playback.completed = data["completed"] as? Bool ?? false
            case "error":
                let code = String(describing: data["code"] ?? "unknown")
                switch code {
                case "100": playback.error = "This video is private or no longer available. Try another link."
                case "101", "150": playback.error = "This creator has disabled playback in other apps. Try another video."
                case "live": playback.error = "Live streams don’t have fixed parts yet. Try a recorded video."
                case "153": playback.error = "YouTube couldn’t verify this player. You can open the original below."
                default: playback.error = "YouTube couldn’t load this video. Check your connection or try another link."
                }
            default: break
            }
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            playback.error = "Couldn’t connect to YouTube. Check your connection and reopen this video."
        }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if action.navigationType == .linkActivated, let url = action.request.url,
               ["https", "http"].contains(url.scheme ?? "") {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else { decisionHandler(.allow) }
        }
    }
}
