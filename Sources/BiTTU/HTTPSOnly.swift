import Foundation
import WebKit

/// HTTPS-only mode: plain-HTTP loads are stopped and replaced with a warning
/// page. The user can keep the insecure load for that host, once, and the
/// exception lasts for the browsing session.
enum HTTPSOnly {
    static private(set) var isEnabled = true
    static private(set) var exceptions: Set<String> = []

    static func setEnabled(_ on: Bool) {
        isEnabled = on
        NSLog("BiTTU HTTPS-only mode " + (on ? "enabled" : "disabled"))
    }

    static func allow(host: String) {
        exceptions.insert(host.lowercased())
    }

    static func isAllowed(host: String) -> Bool {
        exceptions.contains(host.lowercased())
    }

    static func shouldWarn(url: URL) -> Bool {
        guard isEnabled, url.scheme == "http" || url.scheme == "ws" else { return false }
        guard let host = url.host, !host.isEmpty else { return false }
        return !isAllowed(host: host)
    }

    /// The standalone warning page. Tapping "Go to the insecure site" posts
    /// back through the bittuHttps script-message handler, which allows the
    /// host for this session and loads it.
    static func warningPage(for url: URL) -> String {
        let display = url.absoluteString
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"', with: "&quot;")
        return """
        <!DOCTYPE html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body { font-family: -apple-system, sans-serif; background: #1c1c2e; color: #e8e8f0;
                   display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
            .card { max-width: 30rem; padding: 2rem; background: #262640; border-radius: 12px; }
            h1 { margin-top: 0; font-size: 1.3rem; }
            .url { color: #a9a9ff; word-break: break-all; font-size: .85rem; }
            p { line-height: 1.5; font-size: .95rem; }
            button { margin-top: 1rem; padding: .7rem 1.2rem; border-radius: 8px; border: 0;
                     font-size: .95rem; cursor: pointer; }
            .back { background: #4f46e5; color: white; }
            .go { background: transparent; color: #e8e8f0; border: 1px solid #4b4b6b; margin-left: .5rem; }
        </style></head><body>
        <div class="card">
            <h1>&#128274; BiTTU blocked an insecure connection</h1>
            <p class="url">\(display)</p>
            <p>The connection is not encrypted, so anything you send — passwords,
               messages, payments — could be read or changed by anyone on the
               network. A secure version may not exist.</p>
            <button class="back" onclick="history.back()">Go back</button>
            <button class="go"
                    onclick="webkit.messageHandlers.bittuHttps.postMessage(this.dataset.url)"
                    data-url="\(display)">Continue to insecure site</button>
        </div></body></html>
        """
    }

    /// Handles the warning-page button. Returns true when it consumed the message.
    static func handleMessage(_ body: Any) -> Bool {
        guard let urlString = body as? String,
              let url = URL(string: urlString),
              let host = url.host else { return false }
        allow(host: host)
        return true
    }
}