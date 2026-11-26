import Foundation

struct Bookmark: Codable, Equatable {
    var title: String
    var url: String
    var added: Date
}

struct HistoryEntry: Codable, Equatable {
    var title: String
    var url: String
    var visited: Date
}

struct SearchEngine: Codable, Equatable {
    var name: String
    /// URL template containing {query}.
    var template: String
}

/// All local, on-disk user data: bookmarks, history and search engines.
/// Everything lives in ~/Library/Application Support/BiTTU as plain JSON —
/// nothing leaves the machine, and private tabs never touch history.
final class UserData {
    static let shared = UserData()

    private let dir: URL
    private let lock = NSLock()

    private(set) var bookmarks: [Bookmark] = []
    private(set) var history: [HistoryEntry] = []
    private(set) var engines: [SearchEngine] = []
    private(set) var defaultEngineName: String

    static let builtInEngines: [SearchEngine] = [
        SearchEngine(name: "DuckDuckGo", template: "https://duckduckgo.com/?q={query}"),
        SearchEngine(name: "Startpage", template: "https://www.startpage.com/sp/search?query={query}"),
        SearchEngine(name: "Mojeek", template: "https://www.mojeek.com/search?q={query}"),
        SearchEngine(name: "Google", template: "https://www.google.com/search?q={query}"),
        SearchEngine(name: "Bing", template: "https://www.bing.com/search?q={query}"),
    ]

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        dir = base.appendingPathComponent("BiTTU", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        bookmarks = Self.load([Bookmark].self, from: dir.appendingPathComponent("bookmarks.json"))
        history = Self.load([HistoryEntry].self, from: dir.appendingPathComponent("history.json"))

        var stored = Self.load([SearchEngine].self, from: dir.appendingPathComponent("engines.json"))
        if stored.isEmpty { stored = Self.builtInEngines }
        engines = stored

        let storedDefault = Self.load(String.self, from: dir.appendingPathComponent("default-engine.json"))
        if let raw = storedDefault, engines.contains(where: { $0.name == raw }) {
            defaultEngineName = raw
        } else {
            defaultEngineName = "DuckDuckGo"
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T, to name: String) {
        let url = dir.appendingPathComponent(name)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(value) {
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: Bookmarks

    @discardableResult
    func addBookmark(title: String, url: String) -> Bool {
        guard !isBookmarked(url: url) else { return false }
        lock.lock(); defer { lock.unlock() }
        bookmarks.append(Bookmark(title: title.isEmpty ? url : title, url: url, added: Date()))
        save(bookmarks, to: "bookmarks.json")
        return true
    }

    func removeBookmark(url: String) {
        lock.lock(); defer { lock.unlock() }
        bookmarks.removeAll { $0.url == url }
        save(bookmarks, to: "bookmarks.json")
    }

    func isBookmarked(url: String) -> Bool {
        bookmarks.contains { $0.url == url }
    }

    /// Export bookmarks as JSON via an NSSavePanel; returns the file URL on success.
    @MainActor
    func exportBookmarks() -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "BiTTU-Bookmarks.json"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let target = panel.url else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(bookmarks) else { return nil }
        do {
            try data.write(to: target, options: .atomic)
            return target
        } catch {
            NSLog("BiTTU bookmark export failed: " + error.localizedDescription)
            return nil
        }
    }

    // MARK: History

    func recordVisit(title: String, url: URL, isPrivate: Bool) {
        guard !isPrivate else { return }
        let entry = HistoryEntry(title: title.isEmpty ? url.absoluteString : title,
                                 url: url.absoluteString, visited: Date())
        lock.lock(); defer { lock.unlock() }
        history.removeAll { $0.url == entry.url }
        history.append(entry)
        if history.count > 2000 { history.removeFirst(history.count - 2000) }
        save(history, to: "history.json")
    }

    func clearHistory() {
        lock.lock(); defer { lock.unlock() }
        history.removeAll()
        save(history, to: "history.json")
    }

    // MARK: Search engines

    var defaultEngine: SearchEngine? {
        engines.first { $0.name == defaultEngineName }
    }

    func setDefaultEngine(named name: String) {
        guard engines.contains(where: { $0.name == name }) else { return }
        defaultEngineName = name
        save(name, to: "default-engine.json")
    }

    @discardableResult
    func addEngine(name: String, template: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTemplate = template.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedTemplate.isEmpty,
              trimmedTemplate.contains("{query}"),
              URL(string: trimmedTemplate.replacingOccurrences(of: "{query}", with: "x")) != nil,
              !engines.contains(where: { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame })
        else { return false }
        lock.lock(); defer { lock.unlock() }
        engines.append(SearchEngine(name: trimmedName, template: trimmedTemplate))
        save(engines, to: "engines.json")
        return true
    }

    func removeEngine(named name: String) {
        lock.lock(); defer { lock.unlock() }
        engines.removeAll { $0.name == name }
        if defaultEngineName == name { defaultEngineName = engines.first?.name ?? "DuckDuckGo" }
        save(engines, to: "engines.json")
        save(defaultEngineName, to: "default-engine.json")
    }

    /// Resolve raw address-bar input with the chosen engine's template,
    /// falling back to DuckDuckGo when no custom engine matches.
    func searchURL(for raw: String) -> URL? {
        let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw
        let query = encoded.replacingOccurrences(of: "+", with: "%2B")
        let template = defaultEngine?.template ?? "https://duckduckgo.com/?q={query}"
        return URL(string: template.replacingOccurrences(of: "{query}", with: query))
    }
}