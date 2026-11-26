import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: BrowserWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        CookiePolicy.load()
        ContentBlocker.compileAll { [weak self] in
            guard let self else { return }
            guard let store = WKContentRuleListStore.default() else {
                self.windowController = BrowserWindowController()
                self.windowController?.showWindow(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
            CookiePolicy.compile(store: store) { _ in
                self.windowController = BrowserWindowController()
                self.windowController?.showWindow(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}