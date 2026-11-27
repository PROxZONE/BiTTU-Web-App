import AppKit
import WebKit

final class BrowserWindowController: NSWindowController, WKNavigationDelegate {
    private var tabs: [Tab] = []
    private var currentTabIndex = 0
    private let permissionGate = PermissionGate()

    // Chrome
    private let chromeView = NSView()
    private let tabStack = NSStackView()
    private let container = NSView()
    private let addressField = NSTextField()
    private let shieldLabel = NSTextField(labelWithString: "SHIELDS ENGAGED · PERMISSIONS BLOCKED")

    // Midnight Instrument: near-black chrome, one green accent (Theme.swift).
    private let chromeColor = Theme.background
    private let chromeText = Theme.foreground
    private let chromeMuted = Theme.muted

    private var currentTab: Tab? {
        guard currentTabIndex >= 0, currentTabIndex < tabs.count else { return nil }
        return tabs[currentTabIndex]
    }

    convenience init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1240, height: 820),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "BiTTU"
        window.minSize = NSSize(width: 760, height: 500)
        window.center()
        window.titlebarAppearsTransparent = true
        Theme.apply(to: window)
        self.init(window: window)
        buildUI()
        newTab(privateMode: false)
    }

    // MARK: UI construction

    private func buildUI() {
        chromeView.wantsLayer = true
        chromeView.layer?.backgroundColor = chromeColor.cgColor
        container.wantsLayer = true
        container.layer?.backgroundColor = Theme.background.cgColor

        let backButton = toolbarButton(symbol: "chevron.left", action: #selector(goBackAction(_:)))
        let forwardButton = toolbarButton(symbol: "chevron.right", action: #selector(goForwardAction(_:)))
        let reloadButton = toolbarButton(symbol: "arrow.clockwise", action: #selector(reloadAction(_:)))
        let stopButton = toolbarButton(symbol: "xmark", action: #selector(stopAction(_:)))

        addressField.placeholderString = "Search DuckDuckGo or enter address"
        Theme.styleField(addressField)
        addressField.focusRingType = .exterior
        addressField.target = self
        addressField.action = #selector(goToAddress(_:))
        addressField.translatesAutoresizingMaskIntoConstraints = false
        addressField.heightAnchor.constraint(equalToConstant: 26).isActive = true

        shieldLabel.font = Theme.mono(10, .semibold)
        shieldLabel.textColor = chromeMuted
        shieldLabel.translatesAutoresizingMaskIntoConstraints = false

        let toolbar = NSStackView(views: [backButton, forwardButton, reloadButton, stopButton, addressField, shieldLabel])
        toolbar.orientation = .horizontal
        toolbar.spacing = 8
        toolbar.alignment = .centerY
        toolbar.setHuggingPriority(.defaultLow, for: .horizontal)
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.setContentHuggingPriority(.defaultLow, for: .horizontal)
        toolbar.arrangedSubviews.last?.setContentHuggingPriority(.defaultLow, for: .horizontal)

        tabStack.orientation = .horizontal
        tabStack.spacing = 4
        tabStack.alignment = .centerY
        tabStack.translatesAutoresizingMaskIntoConstraints = false

        let newTabButton = toolbarButton(symbol: "plus", action: #selector(newTabAction(_:)))
        let privateTabButton = toolbarButton(symbol: "eye.slash", action: #selector(newPrivateTabAction(_:)))
        privateTabButton.toolTip = "New private tab (nothing kept on disk)"
        newTabButton.toolTip = "New tab"

        let tabBar = NSStackView(views: [tabStack, newTabButton, privateTabButton])
        tabBar.orientation = .horizontal
        tabBar.spacing = 6
        tabBar.alignment = .centerY
        tabBar.translatesAutoresizingMaskIntoConstraints = false

        chromeView.addSubview(toolbar)
        chromeView.addSubview(tabBar)
        container.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(chromeView)
        content.addSubview(container)

        window?.contentView = content
        window?.toolbarStyle = .unified

        NSLayoutConstraint.activate([
            content.widthAnchor.constraint(greaterThanOrEqualToConstant: 760),
            chromeView.topAnchor.constraint(equalTo: content.topAnchor),
            chromeView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            chromeView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            chromeView.bottomAnchor.constraint(equalTo: container.topAnchor),

            toolbar.topAnchor.constraint(equalTo: chromeView.topAnchor, constant: 34),
            toolbar.leadingAnchor.constraint(equalTo: chromeView.leadingAnchor, constant: 12),
            toolbar.trailingAnchor.constraint(equalTo: chromeView.trailingAnchor, constant: -12),

            tabBar.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 6),
            tabBar.leadingAnchor.constraint(equalTo: chromeView.leadingAnchor, constant: 12),
            tabBar.trailingAnchor.constraint(lessThanOrEqualTo: chromeView.trailingAnchor, constant: -12),
            tabBar.bottomAnchor.constraint(equalTo: chromeView.bottomAnchor, constant: -4),

            container.topAnchor.constraint(equalTo: chromeView.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
    }

    private func toolbarButton(symbol: String, action: Selector) -> NSButton {
        let button = NSButton()
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: symbol)
        button.imagePosition = .imageOnly
        button.target = self
        button.action = action
        Theme.styleButton(button)
        button.contentTintColor = chromeText
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 30).isActive = true
        button.heightAnchor.constraint(equalToConstant: 26).isActive = true
        return button
    }

    // MARK: Tabs

    func newTab(privateMode: Bool) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = privateMode ? .nonPersistent() : .default()
        for list in ContentBlocker.sharedRuleLists {
            config.contentRuleLists.append(list)
        }

        let tab = Tab(isPrivate: privateMode, configuration: config)
        tab.webView.navigationDelegate = self
        tab.webView.uiDelegate = permissionGate
        tab.webView.allowsBackForwardNavigationGestures = true
        tab.webView.translatesAutoresizingMaskIntoConstraints = false
        tab.onStateChange = { [weak self] in self?.refreshChrome() }

        tab.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: [.new], context: nil)
        tab.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: [.new], context: nil)

        tabs.append(tab)
        currentTabIndex = tabs.count - 1

        container.subviews.forEach { $0.removeFromSuperview() }
        container.addSubview(tab.webView)
        NSLayoutConstraint.activate([
            tab.webView.topAnchor.constraint(equalTo: container.topAnchor),
            tab.webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tab.webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tab.webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        refreshChrome()
        addressField.window?.makeFirstResponder(addressField)
    }

    private func closeCurrentTab() {
        guard let tab = currentTab else { return }
        tab.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.title))
        tab.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.url))
        tab.webView.stopLoading()
        tabs.removeAll { $0.id == tab.id }
        currentTabIndex = min(currentTabIndex, max(tabs.count - 1, 0))
        container.subviews.forEach { $0.removeFromSuperview() }
        if let next = currentTab {
            container.addSubview(next.webView)
            NSLayoutConstraint.activate([
                next.webView.topAnchor.constraint(equalTo: container.topAnchor),
                next.webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                next.webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                next.webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        } else {
            window?.close()
            return
        }
        refreshChrome()
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        DispatchQueue.main.async { [weak self] in self?.refreshChrome() }
    }

    // MARK: Chrome refresh

    private func refreshChrome() {
        guard let tab = currentTab else { return }

        tabStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, item) in tabs.enumerated() {
            let active = index == currentTabIndex
            let title = (item.isPrivate ? "Private · " : "") + item.title
            let button = NSButton(title: title, target: self, action: #selector(selectTabAction(_:)))
            button.isBordered = false
            button.focusRingType = .exterior
            button.attributedTitle = NSAttributedString(string: title, attributes: [
                .font: Theme.mono(11, active ? .semibold : .regular),
                .foregroundColor: active ? Theme.accent : chromeMuted,
            ])
            button.wantsLayer = true
            button.layer?.cornerRadius = Theme.radius
            button.layer?.backgroundColor = (active ? Theme.raised : NSColor.clear).cgColor
            button.tag = index
            button.lineBreakMode = .byTruncatingTail
            button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            button.widthAnchor.constraint(lessThanOrEqualToConstant: 160).isActive = true
            tabStack.addArrangedSubview(button)
        }

        addressField.stringValue = tab.webView.url?.absoluteString ?? ""
        shieldLabel.attributedStringValue = Theme.eyebrow(tab.isPrivate
            ? "Shields engaged · private tab · permissions blocked"
            : "Shields engaged · permissions blocked")
        window?.title = tab.title
    }

    // MARK: Actions (menu + buttons)

    @objc func newTabAction(_ sender: Any?) { newTab(privateMode: false) }
    @objc func newPrivateTabAction(_ sender: Any?) { newTab(privateMode: true) }
    @objc func closeTabAction(_ sender: Any?) { closeCurrentTab() }

    @objc func selectTabAction(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < tabs.count else { return }
        currentTabIndex = sender.tag
        container.subviews.forEach { $0.removeFromSuperview() }
        let tab = tabs[currentTabIndex]
        container.addSubview(tab.webView)
        NSLayoutConstraint.activate([
            tab.webView.topAnchor.constraint(equalTo: container.topAnchor),
            tab.webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tab.webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tab.webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        refreshChrome()
    }

    @objc func goBackAction(_ sender: Any?) { currentTab?.webView.goBack() }
    @objc func goForwardAction(_ sender: Any?) { currentTab?.webView.goForward() }
    @objc func reloadAction(_ sender: Any?) { currentTab?.webView.reload() }
    @objc func stopAction(_ sender: Any?) { currentTab?.webView.stopLoading() }

    @objc private func goToAddress(_ sender: Any?) {
        guard let tab = currentTab, let url = SecurityPolicy.requestURL(from: addressField.stringValue) else { return }
        tab.webView.load(URLRequest(url: url))
        refreshChrome()
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard SecurityPolicy.navigationAllowed(navigationAction.request) else {
            decisionHandler(.cancel)
            return
        }
        if let upgraded = SecurityPolicy.upgraded(navigationAction.request.url), upgraded != navigationAction.request.url {
            decisionHandler(.cancel)
            webView.load(URLRequest(url: upgraded))
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation?) { refreshChrome() }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) { refreshChrome() }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: Error) {
        refreshChrome()
    }
}