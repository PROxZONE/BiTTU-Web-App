import Foundation
import WebKit

/// Cookie policy / first-party isolation.
enum CookiePolicy {
    enum Mode: String, CaseIterable, Codable {
        case allowAll = "allow-all"
        case blockThirdParty = "block-third-party"
        case blockAll = "block-all"

        var label: String {
            switch self {
            case .allowAll: return "Allow cookies"
            case .blockThirdParty: return "Block third-party cookies (first-party isolation)"
            case .blockAll: return "Block all cookies"
            }
        }
    }

    static let ruleListIdentifier = "bittu-cookie-policy"
    private static let prefsURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        return base.appendingPathComponent("BiTTU/cookie-policy.json")
    }()

    static private(set) var mode: Mode = .blockThirdParty
    static private(set) var compiled: WKContentRuleList?

    static func load() {
        if let data = try? Data(contentsOf: prefsURL),
           let saved = try? JSONDecoder().decode(Mode.self, from: data) {
            mode = saved
        }
    }

    static func set(_ newMode: Mode) {
        mode = newMode
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(newMode) {
            try? data.write(to: prefsURL, options: .atomic)
        }
        NSLog("BiTTU cookie policy set to " + newMode.rawValue)
    }

    static func rulesJSON() -> String? {
        var rules: [[String: Any]] = []
        switch mode {
        case .allowAll:
            return nil
        case .blockThirdParty:
            rules.append([
                "trigger": ["url-filter": ".*", "load-type": ["third-party"]],
                "action": ["type": "block-cookies"],
            ])
        case .blockAll:
            rules.append([
                "trigger": ["url-filter": ".*"],
                "action": ["type": "block-cookies"],
            ])
        }
        guard JSONSerialization.isValidObject(rules) else { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: rules) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func compile(store: WKContentRuleListStore,
                        completion: @escaping (WKContentRuleList?) -> Void) {
        guard mode != .allowAll else {
            completion(nil)
            return
        }
        let fallbackDict: [String: Any] = [
            "trigger": ["url-filter": ".*"],
            "action": ["type": "block-cookies"],
        ]
        let fallbackData = JSONSerialization.data(withJSONObject: [fallbackDict])
        let fallback = String(data: fallbackData, encoding: .utf8) ?? "[]"
        let json = rulesJSON() ?? fallback
        store.compileContentRuleList(forIdentifier: ruleListIdentifier,
                                     encodedContentRuleList: json) { list, error in
            if let error {
                NSLog("BiTTU cookie policy failed to compile: " + error.localizedDescription)
            }
            completion(list)
            DispatchQueue.main.async { compiled = list }
        }
    }
}