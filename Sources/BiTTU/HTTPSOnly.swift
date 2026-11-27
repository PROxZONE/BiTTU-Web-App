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

    /// HTML-escapes a URL for safe interpolation into the warning page.
    static func escapedHTML(_ text: String) -> String {
        let quote = Character(UnicodeScalar(34))
        var out = text
        out = out.replacingOccurrences(of: String(Character(UnicodeScalar(38))), with: "&amp;")
        out = out.replacingOccurrences(of: "<", with: "&lt;")
        out = out.replacingOccurrences(of: ">", with: "&gt;")
        out = out.replacingOccurrences(of: String(quote), with: "&quot;")
        return out
    }

    /// The standalone warning page. Tapping "Continue to insecure site" posts
    /// back through the bittuHttps script-message handler, which allows the
    /// host for this session and loads it.
    static func warningPage(for url: URL) -> String {
        let display = escapedHTML(url.absoluteString)
        return """
        <!DOCTYPE html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            :root {
                color-scheme: dark;
                --bg: #0A0E14; --surface: #11161F; --raised: #161D28; --border: #25303D;
                --fg: #DCE6F2; --heading: #F3F8FF; --muted: #8E9DB1;
                --accent: #5BE49B; --accent-ink: #06281A; --radius: 6px;
            }
            * { box-sizing: border-box; }
            body { margin: 0; min-height: 100vh; padding: 24px;
                   display: flex; align-items: center; justify-content: center;
                   background: var(--bg); color: var(--fg);
                   font: 400 15px/1.6 "SF Mono", ui-monospace, Menlo, monospace; }
            .card { width: 100%; max-width: 30rem; padding: 28px;
                    background: var(--surface); border: 1px solid var(--border);
                    border-radius: var(--radius); }
            .eyebrow { margin: 0 0 14px; font-size: 11px; font-weight: 600;
                       letter-spacing: .09em; text-transform: uppercase; color: var(--muted); }
            h1 { margin: 0 0 12px; font-size: 20px; line-height: 1.35;
                 font-weight: 600; color: var(--heading); }
            .url { margin: 0 0 16px; font-size: 13px; color: var(--accent); word-break: break-all; }
            p { margin: 0; line-height: 1.6; }
            .actions { display: flex; flex-wrap: wrap; gap: 10px; margin-top: 22px; }
            button { min-height: 40px; padding: 10px 16px; border-radius: var(--radius);
                     border: 1px solid var(--border); background: var(--raised); color: var(--fg);
                     font: 600 13px/1 "SF Mono", ui-monospace, Menlo, monospace; cursor: pointer; }
            button.primary { background: var(--accent); color: var(--accent-ink); border-color: transparent; }
            button:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
            @media (prefers-reduced-motion: no-preference) {
                button { transition: background-color .15s ease, border-color .15s ease; }
                button:hover { border-color: var(--accent); }
                button.primary:hover { background: #7BEDB0; }
            }
            @media (max-width: 420px) { .card { padding: 20px; } button { width: 100%; } }
        </style></head><body>
        <div class="card">
            <p class="eyebrow">Shields engaged &#183; insecure request</p>
            <h1>This page would travel unencrypted.</h1>
            <p class="url">\(display)</p>
            <p>Anything you send here &#8212; passwords, messages, payments &#8212; can be
               read or changed by anyone on this network. BiTTU tried HTTPS first and
               found no secure version behind this address.</p>
            <div class="actions">
                <button class="primary" onclick="history.back()">Go back</button>
                <button class="go"
                        onclick="webkit.messageHandlers.bittuHttps.postMessage(this.dataset.url)"
                        data-url="\(display)">Continue to insecure site</button>
            </div>
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