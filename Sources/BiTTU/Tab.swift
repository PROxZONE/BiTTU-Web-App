import Foundation
import WebKit

final class Tab: NSObject {
    let id = UUID()
    let isPrivate: Bool
    let webView: SecureWebView

    init(isPrivate: Bool, configuration: WKWebViewConfiguration) {
        self.isPrivate = isPrivate
        self.webView = SecureWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.tab = self
        // Dark chrome, dark paper: no white flash before a page paints.
        webView.underPageBackgroundColor = Theme.background
    }

    var title: String {
        if let title = webView.title, !title.isEmpty { return title }
        if let host = webView.url?.host { return host }
        return isPrivate ? "Private Tab" : "New Tab"
    }
}