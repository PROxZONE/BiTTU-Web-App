import AppKit
import WebKit

/// Denies every web permission WKWebView can ask for, and blocks every popup.
final class PermissionGate: NSObject, WKUIDelegate {

    // MARK: Permissions — always denied

    func webView(_ webView: WKWebView,
                 requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        NSLog("BiTTU denied media capture (\(type.rawValue)) for origin \(origin.host)")
        decisionHandler(.deny)
    }

    func webView(_ webView: WKWebView,
                 requestDeviceOrientationAndMotionPermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        NSLog("BiTTU denied device motion/orientation for origin \(origin.host)")
        decisionHandler(.deny)
    }

    // MARK: Popups — always blocked

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        NSLog("BiTTU blocked popup → \(navigationAction.request.url?.absoluteString ?? "unknown")")
        return nil
    }

    // MARK: JavaScript dialogs

    private func sheet(for webView: WKWebView, title: String, message: String,
                       confirmLabel: String, showCancel: Bool) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = title.isEmpty ? "JavaScript" : title
        alert.informativeText = message
        alert.addButton(withTitle: confirmLabel)
        if showCancel { alert.addButton(withTitle: "Cancel") }
        alert.alertStyle = .warning
        return alert
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let alert = sheet(for: webView, title: frame.request.url?.host ?? "", message: message, confirmLabel: "OK", showCancel: false)
        if let window = webView.window {
            alert.beginSheetModal(for: window) { _ in completionHandler() }
        } else {
            _ = alert.runModal()
            completionHandler()
        }
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let alert = sheet(for: webView, title: frame.request.url?.host ?? "", message: message, confirmLabel: "OK", showCancel: true)
        let handler: (NSApplication.ModalResponse) -> Void = { response in
            completionHandler(response == .alertFirstButtonReturn)
        }
        if let window = webView.window {
            alert.beginSheetModal(for: window, completionHandler: handler)
        } else {
            handler(alert.runModal())
        }
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        let alert = sheet(for: webView, title: frame.request.url?.host ?? "", message: prompt, confirmLabel: "OK", showCancel: true)
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.stringValue = defaultText ?? ""
        alert.accessoryView = field
        field.nextKeyView = alert.buttons.first

        let handler: (NSApplication.ModalResponse) -> Void = { response in
            completionHandler(response == .alertFirstButtonReturn ? field.stringValue : nil)
        }
        if let window = webView.window {
            alert.beginSheetModal(for: window, completionHandler: handler)
        } else {
            handler(alert.runModal())
        }
    }
}