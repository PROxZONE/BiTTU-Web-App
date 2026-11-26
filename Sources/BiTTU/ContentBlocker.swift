import Foundation
import WebKit

/// Compiles every bundled rule list into WKContentRuleLists and exposes them
/// so every new tab is protected from its first request.
enum ContentBlocker {
    static private(set) var sharedRuleLists: [WKContentRuleList] = []

    static func compileAll(completion: @escaping () -> Void) {
        guard let store = WKContentRuleListStore.default() else {
            NSLog("BiTTU: no content rule list store available")
            completion()
            return
        }

        let files = blocklistFiles()
        guard !files.isEmpty else {
            NSLog("BiTTU: no blocklists bundled")
            completion()
            return
        }

        let group = DispatchGroup()
        var compiled: [WKContentRuleList] = []
        let lock = NSLock()

        for (name, url) in files {
            guard let json = try? String(contentsOf: url, encoding: .utf8) else {
                NSLog("BiTTU: could not read blocklist " + name)
                continue
            }
            group.enter()
            store.compileContentRuleList(forIdentifier: name, encodedContentRuleList: json) { list, error in
                if let list {
                    lock.lock(); compiled.append(list); lock.unlock()
                } else if let error {
                    NSLog("BiTTU: blocklist " + name + " failed to compile: " + error.localizedDescription)
                } 
                group.leave()
            }
        }

        group.notify(queue: .main) {
            sharedRuleLists = compiled.sorted { $0.identifier < $1.identifier }
            NSLog("BiTTU: " + String(sharedRuleLists.count) + "/" + String(files.count) + " blocklists active")
            completion()
        }
    }

    private static func blocklistFiles() -> [(String, URL)] {
        guard let base = Bundle.module.url(forResource: "blocklists", withExtension: nil, subdirectory: "Resources")
            ?? Bundle.module.url(forResource: "blocklists", withExtension: nil) else {
            return []
        }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: base.path)) ?? []
        return names
            .filter { $0.hasSuffix(".json") }
            .sorted()
            .compactMap { name in
                let url = base.appendingPathComponent(name)
                return (String(name.dropLast(5)), url)
            }
    }
}