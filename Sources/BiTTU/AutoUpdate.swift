import AppKit
import Sparkle

// Phase 4 (Distribution): Sparkle-based auto-update.
//
// The update feed and EdDSA signature key live in the bundle's Info.plist
// (SUFeedURL, SUPublicEDKey); make-app.sh injects them at bundle time. When
// either key is missing (a dev build outside CI), updating is disabled and
// the menu item is hidden rather than letting Sparkle error at launch.
final class AutoUpdater: NSObject {
    static let shared = AutoUpdater()

    private var controller: SPUStandardUpdaterController?
    private(set) var isEnabled = false

    func start() {
        guard Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil else {
            NSLog("BiTTU auto-update: no SUFeedURL in Info.plist — updates disabled")
            return
        }
        let updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        controller = updaterController
        isEnabled = true
    }

    var canCheckForUpdates: Bool { isEnabled }

    func checkForUpdates(_ sender: Any?) {
        controller?.checkForUpdates(sender)
    }
}