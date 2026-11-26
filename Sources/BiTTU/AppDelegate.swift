import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: BrowserWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AutoUpdater.shared.start()
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
        buildMenus()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func buildMenus() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About BiTTU", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        if AutoUpdater.shared.isEnabled {
            let checkItem = appMenu.addItem(withTitle: "Check for Updates…", action: #selector(AutoUpdater.checkForUpdates(_:)), keyEquivalent: "u")
            checkItem.target = AutoUpdater.shared
            appMenu.addItem(.separator())
        }
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit BiTTU", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New Tab", action: #selector(BrowserWindowController.newTabAction(_:)), keyEquivalent: "t")
        let privateItem = fileMenu.addItem(withTitle: "New Private Tab", action: #selector(BrowserWindowController.newPrivateTabAction(_:)), keyEquivalent: "n")
        privateItem.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(.separator())
        let closeItem = fileMenu.addItem(withTitle: "Close Tab", action: #selector(BrowserWindowController.closeTabAction(_:)), keyEquivalent: "w")
        closeItem.keyEquivalentModifierMask = [.command, .option]
        fileItem.submenu = fileMenu
        mainMenu.addItem(fileItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "p")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        let viewItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "Reload", action: #selector(BrowserWindowController.reloadAction(_:)), keyEquivalent: "r")
        let forceItem = viewMenu.addItem(withTitle: "Stop", action: #selector(BrowserWindowController.stopAction(_:)), keyEquivalent: ".")
        forceItem.keyEquivalentModifierMask = [.command]
        viewItem.submenu = viewMenu
        mainMenu.addItem(viewItem)

        NSApp.mainMenu = mainMenu
    }
}