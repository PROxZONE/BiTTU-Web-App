import Foundation

/// Per-site shield state: which hosts have content blocking turned down.
/// Persisted locally; hosts not in the set always have shields up.
final class Shields {
    static let shared = Shields()

    private let url: URL
    private let lock = NSLock()
    private(set) var disabledHosts: Set<String> = []

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        url = base.appendingPathComponent("BiTTU/shields.json")
        if let data = try? Data(contentsOf: url),
           let hosts = try? JSONDecoder().decode(Set<String>.self, from: data) {
            disabledHosts = hosts
        }
    }

    func isEnabled(forHost host: String?) -> Bool {
        guard let host, !host.isEmpty else { return true }
        lock.lock(); defer { lock.unlock() }
        return !disabledHosts.contains(host.lowercased())
    }

    /// Toggle shields for a host; returns the new state (true = enabled).
    @discardableResult
    func toggle(host: String) -> Bool {
        let key = host.lowercased()
        lock.lock()
        if disabledHosts.contains(key) {
            disabledHosts.remove(key)
        } else {
            disabledHosts.insert(key)
        }
        let enabled = !disabledHosts.contains(key)
        lock.unlock()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(disabledHosts) {
            try? data.write(to: url, options: .atomic)
        }
        NSLog("BiTTU shields " + (enabled ? "up" : "down") + " for " + key)
        return enabled
    }
}