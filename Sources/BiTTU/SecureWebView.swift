import WebKit

final class SecureWebView: WKWebView {
    weak var tab: Tab?
    var onStateChange: (() -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        onStateChange?()
    }
}