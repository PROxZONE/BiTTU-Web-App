import AppKit
import WebKit

/// Simple list windows for bookmarks and history, and the search-engine
/// settings window. Rows are clickable to open the URL in the main browser.
enum LibraryWindows {
    static private var bookmarksWindow: NSWindow?
    static private var historyWindow: NSWindow?
    static private(set) weak var browser: BrowserWindowController?
    static private var enginesWindow: NSWindow?


    static func attach(browser: BrowserWindowController) {
        self.browser = browser
    }

    // MARK: Window shell

    /// One dark window per library screen; rebuilt content inherits the theme.
    private static func reuse(_ slot: inout NSWindow?, title: String, width: CGFloat, height: CGFloat) -> NSWindow {
        let window: NSWindow
        if let existing = slot {
            window = existing
        } else {
            window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            slot = window
        }
        window.title = title
        Theme.apply(to: window)
        if let content = window.contentView { Theme.fill(content, Theme.background) }
        return window
    }

    /// Mono body text; muted for helper copy, foreground for content.
    private static func label(_ text: String, muted: Bool = true) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.attributedStringValue = NSAttributedString(string: text, attributes: [
            .font: Theme.mono(11.5),
            .foregroundColor: muted ? Theme.muted : Theme.foreground,
        ])
        return field
    }

    private static func eyebrow(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.attributedStringValue = Theme.eyebrow(text)
        return field
    }

    // MARK: Bookmarks

    static func showBookmarks() {
        let window = reuse(&bookmarksWindow, title: "Bookmarks", width: 520, height: 400)
        rebuildBookmarkRows(in: window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func rebuildBookmarkRows(in window: NSWindow) {
        window.contentView?.subviews.forEach { $0.removeFromSuperview() }
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        let data = UserData.shared
        stack.addArrangedSubview(eyebrow("Bookmarks · local only"))
        if data.bookmarks.isEmpty {
            stack.addArrangedSubview(label("No bookmarks yet. Press ⌘D on a page to add one."))
        }
        for bookmark in data.bookmarks {
            let row = NSStackView(views: [openButton(title: bookmark.title, urlString: bookmark.url),
                                          deleteButton(kind: .bookmark, key: bookmark.url)])
            row.spacing = 8
            stack.addArrangedSubview(row)
        }
        window.contentView?.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: window.contentView!.trailingAnchor, constant: -16),
        ])
    }

    // MARK: History

    static func showHistory() {
        let window = reuse(&historyWindow, title: "History", width: 560, height: 420)
        window.contentView?.subviews.forEach { $0.removeFromSuperview() }
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        let entries = UserData.shared.history.reversed()
        stack.addArrangedSubview(eyebrow("History · this device only"))
        if entries.isEmpty {
            stack.addArrangedSubview(label("History is empty. Private tabs are never recorded."))
        }
        let formatter = RelativeDateTimeFormatter()
        for entry in entries {
            let when = formatter.localizedString(for: entry.visited, relativeTo: Date())
            let row = NSStackView(views: [
                openButton(title: when + "  " + entry.title, urlString: entry.url),
            ])
            row.spacing = 8
            stack.addArrangedSubview(row)
        }

        let clear = NSButton(title: "Clear History", target: nil, action: nil)
        Theme.styleTextButton(clear)
        clear.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(stack)
        window.contentView?.addSubview(clear)
        NSLayoutConstraint.activate([
            clear.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor, constant: -12),
            clear.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: window.contentView!.trailingAnchor, constant: -16),
        ])
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func clearAllHistory() {
        UserData.shared.clearHistory()
        showHistory()
    }

    // MARK: Search engines

    static func showSearchEngines() {
        let window = reuse(&enginesWindow, title: "Search Engines", width: 520, height: 380)
        window.contentView?.subviews.forEach { $0.removeFromSuperview() }
        let data = UserData.shared

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(eyebrow("Search engines · local only"))
        stack.addArrangedSubview(label("Default engine used for address-bar searches:", muted: false))

        for engine in data.engines {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 8
            let pick = NSButton(title: engine.name, target: nil, action: nil)
            pick.bezelStyle = .rounded
            pick.keyEquivalent = engine.name == data.defaultEngineName ? "●" : ""
            pick.keyEquivalentModifierMask = []
            pick.target = LibraryWindows.sharedTarget
            pick.action = #selector(LibraryTarget.pickEngine(_:))
            pick.identifier = NSUserInterfaceItemIdentifier(engine.name)
            row.addArrangedSubview(pick)
            let remove = NSButton(title: "Remove", target: nil, action: nil)
            remove.bezelStyle = .rounded
            remove.target = LibraryWindows.sharedTarget
            remove.action = #selector(LibraryTarget.removeEngine(_:))
            remove.identifier = NSUserInterfaceItemIdentifier(engine.name)
            row.addArrangedSubview(remove)
            stack.addArrangedSubview(row)
        }

        let nameField = NSTextField(string: "")
        nameField.placeholderString = "Engine name"
        Theme.styleField(nameField, size: 11.5)
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.widthAnchor.constraint(equalToConstant: 150).isActive = true
        nameField.heightAnchor.constraint(equalToConstant: 24).isActive = true
        let templateField = NSTextField(string: "")
        templateField.placeholderString = "URL with {query}, e.g. https://example.com/?q={query}"
        Theme.styleField(templateField, size: 11.5)
        templateField.translatesAutoresizingMaskIntoConstraints = false
        templateField.widthAnchor.constraint(equalToConstant: 280).isActive = true
        templateField.heightAnchor.constraint(equalToConstant: 24).isActive = true
        let add = NSButton(title: "Add Engine", target: LibraryWindows.sharedTarget, action: #selector(LibraryTarget.addEngine(_:)))
        Theme.styleTextButton(add, primary: true)

        let addRow = NSStackView(views: [nameField, templateField, add])
        addRow.orientation = .horizontal
        addRow.spacing = 8
        addRow.translatesAutoresizingMaskIntoConstraints = false

        window.contentView?.addSubview(stack)
        window.contentView?.addSubview(addRow)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: window.contentView!.trailingAnchor, constant: -16),
            addRow.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor, constant: -16),
            addRow.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 16),
        ])
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc static func addEngineClicked(_ sender: Any?) {
        // Filled from the window's own fields by LibraryTarget.addEngine(_:).
    }

    // MARK: Row controls

    private static func openButton(title: String, urlString: String) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        button.isBordered = false
        button.focusRingType = .exterior
        button.lineBreakMode = .byTruncatingTail
        button.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: Theme.mono(11.5),
            .foregroundColor: Theme.foreground,
        ])
        button.contentTintColor = Theme.accent
        button.target = LibraryWindows.sharedTarget
        button.action = #selector(LibraryTarget.openURL(_:))
        button.identifier = NSUserInterfaceItemIdentifier(urlString)
        return button
    }

    private static func deleteButton(kind: DeleteKind, key: String) -> NSButton {
        let button = NSButton(title: kind.label, target: nil, action: nil)
        button.isBordered = false
        button.focusRingType = .exterior
        button.attributedTitle = NSAttributedString(string: kind.label, attributes: [
            .font: Theme.mono(10.5),
            .foregroundColor: Theme.muted,
        ])
        button.contentTintColor = Theme.muted
        button.target = LibraryWindows.sharedTarget
        button.action = kind.selector
        button.identifier = NSUserInterfaceItemIdentifier(key)
        return button
    }

    private enum DeleteKind {
        case bookmark

        var label: String { "Remove" }
        var selector: Selector { #selector(LibraryTarget.removeBookmark(_:)) }
    }

    private static let sharedTarget = LibraryTarget()

    /// Objective-C target for the list-window controls.
    final class LibraryTarget: NSObject {
        @objc func openURL(_ sender: NSButton) {
            guard let raw = sender.identifier?.rawValue, let url = SecurityPolicy.requestURL(from: raw) else { return }
            browser?.load(url: url)
        }

        @objc func removeBookmark(_ sender: NSButton) {
            guard let key = sender.identifier?.rawValue else { return }
            UserData.shared.removeBookmark(url: key)
            showBookmarks()
        }

        @objc func pickEngine(_ sender: NSButton) {
            guard let name = sender.identifier?.rawValue else { return }
            UserData.shared.setDefaultEngine(named: name)
            showSearchEngines()
        }

        @objc func removeEngine(_ sender: NSButton) {
            guard let name = sender.identifier?.rawValue else { return }
            UserData.shared.removeEngine(named: name)
            showSearchEngines()
        }

        @objc func addEngine(_ sender: NSButton) {
            guard let row = sender.superview as? NSStackView,
                  let fields = row.arrangedSubviews.compactMap({ $0 as? NSTextField }).count == 2 ? row.arrangedSubviews.compactMap({ $0 as? NSTextField }) : nil,
                  fields.count == 2 else { return }
            let ok = UserData.shared.addEngine(name: fields[0].stringValue, template: fields[1].stringValue)
            if !ok { NSSound.beep() }
            showSearchEngines()
        }
    }
}