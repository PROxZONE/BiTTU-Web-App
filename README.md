# BiTTU Web App

A secure, privacy-first web browser for macOS, inspired by Brave's approach:
**every web permission is denied by default**, popups are blocked, HTTP is
silently upgraded to HTTPS, and bundled rule lists block ads and trackers —
all wrapped in a clean, indigo-accented chrome.

## What it blocks (on by default)

| Protection | How |
| --- | --- |
| Camera & microphone | `WKMediaCaptureType` requests always denied (`PermissionGate`) |
| Device motion & orientation | permission requests always denied |
| Geolocation prompts | denied (no location permission is ever granted) |
| Popups & auto-redirects to new windows | `createWebViewWith` returns `nil` |
| Insecure traffic | `http://` requests are upgraded to `https://`; `file:`, `ftp:`, `javascript:` and custom schemes are cancelled (`SecurityPolicy`) |
| Ads & trackers | bundled WKContentRuleList blocklists (`Resources/blocklists/`) compiled once and attached to every tab |
| Ad placeholder layout shift | CSS display-none rule for common ad containers |
| Private browsing | private tabs use a non-persistent `WKWebsiteDataStore` — nothing hits disk |

No telemetry, no accounts, no network calls other than the pages you open.

## Build (macOS 13+, Xcode or Swift toolchain)

```bash
git clone https://github.com/PROxZONE/BiTTU-Web-App.git
cd BiTTU-Web-App
swift run              # build and launch in one step
# or make a proper app bundle:
./scripts/make-app.sh
open build/BiTTU.app
```

Every push builds on GitHub Actions macOS runners; the artifact is a
`BiTTU.app` bundle you can download from the workflow run.

## Using the browser

- Type an address, or type words to search DuckDuckGo (privacy-friendly default).
- `⌘T` new tab · `⇧⌘N` new private tab · `⌥⌘W` close tab · `⌘R` reload · `⌘.` stop.
- The shield label in the toolbar always tells you: **Shields up · permissions blocked**.

## Project layout

```
Sources/BiTTU/
  main.swift                  app entry
  AppDelegate.swift           lifecycle + native menus
  BrowserWindowController.swift  chrome, tabs, navigation delegate
  Tab.swift                   one tab = one SecureWebView
  SecureWebView.swift         WKWebView subclass
  PermissionGate.swift        deny camera/mic/motion, block popups, JS dialogs
  SecurityPolicy.swift        URL resolution, scheme filter, HTTPS upgrade
  ContentBlocker.swift        compile + attach rule lists
  Resources/blocklists/       content-blocker rule lists (JSON)
scripts/make-app.sh           bundle build/BiTTU.app
```

## Extending the blocklists

WKContentRuleList supports the Safari content-blocker syntax. Drop any
compatible JSON file into `Sources/BiTTU/Resources/blocklists/` and it is
picked up automatically on the next launch — e.g. a converted EasyList +
EasyPrivacy bundle for Brave-level coverage.

## Roadmap

See [PLAN.md](PLAN.md): bookmarks/history and per-site shields (Phase 2),
fingerprint protection and full EasyList/EasyPrivacy (Phase 3), signed and
notarized builds with auto-update (Phase 4).

## License

MIT.