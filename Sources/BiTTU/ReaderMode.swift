import AppKit
import WebKit

/// Reader mode: extracts the main text of the current page and shows it in a
/// clean, distraction-free window.
enum ReaderMode {
    static private var window: NSWindow?

    private static let extractionJS = """
    (function() {
      var candidates = ['article', 'main', '[role="main"]', '#content', '.post', '.entry-content'];
      var best = null;
      for (var i = 0; i < candidates.length; i++) {
        var el = document.querySelector(candidates[i]);
        if (el && el.innerText && el.innerText.length > (best ? best.innerText.length : 800)) { best = el; }
      }
      var text = (best || document.body).innerText || '';
      return JSON.stringify({ title: document.title, text: text });
    })()
    """

    static func toggle(for tab: Tab?) {
        guard let tab else { return }
        if window?.isVisible == true { window?.close(); return }
        show(for: tab)
    }

    static func show(for tab: Tab) {
        tab.webView.evaluateJavaScript(extractionJS) { result, error in
            DispatchQueue.main.async {
                guard error == nil, let raw = result as? String,
                      let data = raw.data(using: .utf8),
                      let payload = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                      let text = payload["text"], !text.isEmpty else {
                    NSLog("BiTTU reader mode: nothing to extract on " + (tab.webView.url?.absoluteString ?? "?"))
                    return
                }
                present(title: payload["title"] ?? tab.title, url: tab.webView.url, text: text)
            }
        }
    }

    private static func present(title: String, url: URL?, text: String) {
        let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 720),
                             styleMask: [.titled, .closable, .resizable],
                             backing: .buffered, defer: false)
        panel.title = title

        let header = NSTextField(labelWithString: title)
        header.font = .systemFont(ofSize: 20, weight: .semibold)
        header.lineBreakMode = .byWordWrapping
        header.maximumNumberOfLines = 3
        let source = NSTextField(labelWithString: url?.absoluteString ?? "")
        source.font = .systemFont(ofSize: 11)
        source.textColor = .secondaryLabelColor
        source.lineBreakMode = .byTruncatingTail

        let body = NSTextView()
        body.isEditable = false
        body.textContainerInset = NSSize(width: 8, height: 8)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5
        body.textStorage?.setAttributedString(
            NSAttributedString(string: text, attributes: [
                .font: NSFont.systemFont(ofSize: 15),
                .paragraphStyle: paragraph,
            ]))

        let scroll = NSScrollView()
        scroll.documentView = body
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        body.translatesAutoresizingMaskIntoConstraints = false
        body.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -24).isActive = true
        body.heightAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true

        let stack = NSStackView(views: [header, source, scroll])
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.alignment = .leading

        panel.contentView = stack
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: panel.contentLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: panel.contentLayoutGuide.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: panel.contentLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: panel.contentLayoutGuide.trailingAnchor, constant: -24),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 300),
        ])

        window = panel
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}