import AppKit
import WebKit

/// Handles every file download: picks a destination in ~/Downloads, tracks
/// progress and shows the downloads window.
final class DownloadManager: NSObject, WKDownloadDelegate {
    static let shared = DownloadManager()

    struct Item {
        var filename: String
        var url: String
        var expectedBytes: Int64
        var receivedBytes: Int64
        var finished: Bool
        var failed: Bool
        var destination: URL?
    }

    static private(set) var items: [Item] = []
    static var onChange: (() -> Void)?

    static private(set) var window: NSWindow?

    static func startDownload(from response: URLResponse, with download: WKDownload) {
        download.delegate = shared
        let name = response.suggestedFilename ?? "download"
        let expected = response.expectedContentLength
        items.append(Item(filename: name, url: response.url?.absoluteString ?? "unknown",
                          expectedBytes: expected, receivedBytes: 0,
                          finished: false, failed: false, destination: nil))
        showWindow()
        onChange?()
    }

    // MARK: WKDownloadDelegate

    func download(_ download: WKDownload,
                  decideDestinationUsing response: URLResponse,
                  suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void) {
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory() + "/Downloads")
        let clean = suggestedFilename.replacingOccurrences(of: "/", with: "-")
        var target = downloadsDir.appendingPathComponent(clean)
        var bump = 1
        let baseName = target.deletingPathExtension().lastPathComponent
        let ext = target.pathExtension
        while FileManager.default.fileExists(atPath: target.path) {
            let name = ext.isEmpty ? baseName + " (" + String(bump) + ")"
                : baseName + " (" + String(bump) + ")." + ext
            target = downloadsDir.appendingPathComponent(name)
            bump += 1
        }
        if let index = DownloadManager.items.lastIndex(where: { $0.destination == nil && !$0.finished && !$0.failed }) {
            DownloadManager.items[index].destination = target
            DownloadManager.items[index].filename = target.lastPathComponent
        }
        completionHandler(target)
    }

    func download(_ download: WKDownload, didReceive data: Data) {
        guard let index = DownloadManager.items.lastIndex(where: { $0.destination != nil && !$0.finished && !$0.failed }) else { return }
        DownloadManager.items[index].receivedBytes += Int64(data.count)
        DispatchQueue.main.async { DownloadManager.onChange?() }
    }

    func downloadDidFinish(_ download: WKDownload) {
        if let index = DownloadManager.items.lastIndex(where: { !$0.finished && !$0.failed }) {
            DownloadManager.items[index].finished = true
        }
        DispatchQueue.main.async { DownloadManager.onChange?() }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        if let index = DownloadManager.items.lastIndex(where: { !$0.finished && !$0.failed }) {
            DownloadManager.items[index].failed = true
        }
        NSLog("BiTTU download failed: " + error.localizedDescription)
        DispatchQueue.main.async { DownloadManager.onChange?() }
    }

    // MARK: Downloads window

    static func showWindow() {
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }

        let panel = NSPanel(styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = "Downloads"
        panel.setContentSize(NSSize(width: 480, height: 230))
        panel.isFloatingPanel = false
        panel.becomesKeyOnlyIfNeeded = false
        Theme.apply(to: panel)
        if let content = panel.contentView { Theme.fill(content, Theme.surface) }

        let eyebrow = NSTextField(labelWithString: "Downloads")
        eyebrow.attributedStringValue = Theme.eyebrow("Downloads · local only")
        eyebrow.translatesAutoresizingMaskIntoConstraints = false
        let label = NSTextField(labelWithString: "No downloads yet.")
        label.maximumNumberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let refresh = NSButton(title: "Refresh", target: nil, action: nil)
        Theme.styleTextButton(refresh)
        refresh.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView?.addSubview(eyebrow)
        panel.contentView?.addSubview(label)
        panel.contentView?.addSubview(refresh)

        NSLayoutConstraint.activate([
            eyebrow.topAnchor.constraint(equalTo: panel.contentView!.topAnchor, constant: 16),
            eyebrow.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor, constant: 16),
            label.topAnchor.constraint(equalTo: eyebrow.bottomAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: eyebrow.leadingAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: panel.contentView!.trailingAnchor, constant: -16),
            refresh.bottomAnchor.constraint(equalTo: panel.contentView!.bottomAnchor, constant: -12),
            refresh.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor, constant: -12),
        ])

        // Each state reads as its own signal: queued (muted), saved (accent), failed (danger).
        let update: () -> Void = {
            let text = NSMutableAttributedString()
            func append(_ piece: String, _ color: NSColor) {
                text.append(NSAttributedString(string: piece, attributes: [
                    .font: Theme.mono(11.5), .foregroundColor: color,
                ]))
            }

            if DownloadManager.items.isEmpty {
                append("No downloads yet. Files you download land in ~/Downloads.", Theme.muted)
                label.attributedStringValue = text
                return
            }
            let formatter = ByteCountFormatter()
            for (index, item) in DownloadManager.items.enumerated() {
                if index > 0 { append(String(UnicodeScalar(10)), Theme.foreground) }
                append(item.filename + " — ", Theme.foreground)
                if item.failed {
                    append("failed", Theme.danger)
                } else if item.finished {
                    append("saved to " + (item.destination?.path ?? "unknown"), Theme.accent)
                } else {
                    let received = formatter.string(forByteCount: item.receivedBytes)
                    let expected = item.expectedBytes > 0 ? formatter.string(forByteCount: item.expectedBytes) : "?"
                    append(received + " / " + expected, Theme.muted)
                }
            }
            label.attributedStringValue = text
        }
        DownloadManager.onChange = update
        refresh.target = DownloadManager.shared
        refresh.action = #selector(refreshClicked)

        window = panel
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        update()
    }

    @objc private func refreshClicked() {
        DownloadManager.onChange?()
    }
}