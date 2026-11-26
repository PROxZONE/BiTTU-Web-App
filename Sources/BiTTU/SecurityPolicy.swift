import Foundation

enum SecurityPolicy {
    /// Resolve raw address-bar input to a URL: bare domains get https://,
    /// everything else becomes a DuckDuckGo search (privacy-friendly default).
    static func requestURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
        if lower.hasPrefix("https://") || lower.hasPrefix("http://") {
            return upgraded(URL(string: trimmed))
        }

        let looksLikeDomain = !trimmed.contains(" ")
            && trimmed.contains(".")
            && !trimmed.contains("..")
            && trimmed.last != "."
        if looksLikeDomain, let url = URL(string: "https://\(trimmed)") {
            return url
        }

        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        return URL(string: "https://duckduckgo.com/?q=\(encoded)")
    }

    /// Upgrade any http URL to https.
    static func upgraded(_ url: URL?) -> URL? {
        guard let url, url.scheme?.lowercased() == "http" else { return url }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        return components?.url ?? url
    }

    /// Only plain web content is allowed. Everything else (file:, ftp:,
    /// javascript:, custom schemes…) is cancelled and logged.
    static func navigationAllowed(_ request: URLRequest) -> Bool {
        guard let url = request.url,
              let scheme = url.scheme?.lowercased() else {
            NSLog("BiTTU blocked navigation with no URL/scheme")
            return false
        }
        let allowed = (scheme == "https" || scheme == "http")
        if !allowed {
            NSLog("BiTTU blocked non-web scheme \'\(scheme)\' → \(url.absoluteString)")
        }
        return allowed
    }
}