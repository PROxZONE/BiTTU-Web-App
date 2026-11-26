# BiTTU Web App — a secure, Brave-style browser for macOS

## Goal and users
BiTTU is a privacy-first web browser for macOS, written in Swift/AppKit on WKWebView.
Working = `swift build` compiles, the app opens with a tabbed chrome, sites load,
ads/trackers are blocked by bundled rule lists, and **every web permission is denied
by default** (camera, microphone, geolocation, device motion/orientation) with popups
blocked and HTTP silently upgraded to HTTPS. Look: Stripe-inspired — confident indigo
accent, clean dark chrome, clear type. All original, no third-party brand assets.

## Scope
In scope (this run): tabbed browsing, address bar with smart URL/search handling,
tracker & ad blocking, hard permission blocking, HTTPS upgrade, scheme filtering,
private (non-persistent) tabs, JS alert/confirm/prompt panels, `.app` bundling script,
macOS CI builds, public GitHub repo.
Out of scope (later phases): extensions/add-ons, bookmarks & history UI, sync,
Tor windows, fingerprint farbling, per-site shield toggles, auto-update, sandboxed
renderer hardening beyond what WKWebView provides.

## Architecture
- **Swift Package Manager** executable target `BiTTU` (macOS 13+) — no Xcode project
  needed; `swift build` / `scripts/make-app.sh` produce `build/BiTTU.app`.
- **WKWebView** per tab; one shared `WKContentRuleListStore` for compiled blocklists.
- Components:
  - `main.swift` / `AppDelegate.swift` — app lifecycle, native menus (Cmd+T, Cmd+W⌘).
  - `BrowserWindowController.swift` — chrome (toolbar, tab bar), tab management,
    navigation delegate (scheme filter + HTTPS upgrade), address-bar logic.
  - `Tab.swift` — one tab = one `SecureWebView` + private-mode flag.
  - `SecureWebView.swift` — WKWebView subclass (gesture nav, state callbacks).
  - `PermissionGate.swift` — WKUIDelegate: denies camera/mic, motion/orientation,
    blocks all popups (`createWebViewWith:` ⇒ `nil`), hosts JS alert/confirm/prompt.
  - `SecurityPolicy.swift` — URL/search resolution, allowed-scheme filter (https/http
    only), HTTP⇒HTTPS upgrade.
  - `ContentBlocker.swift` — loads and compiles every `Resources/blocklists/*.json`
    into WKContentRuleLists.
- **Data model**: none persisted (privacy by default); private tabs use
  `WKWebsiteDataStore.nonPersistent()`. Normal tabs use the default store.
- **Auth/secrets**: none. No network calls outside page loads. No telemetry.
- **Hosting**: local macOS app; repo on GitHub; CI builds on macOS runners.

## Risks and assumptions
- This workspace is Linux: Swift/AppKit cannot be compiled here. Verification is via
  the GitHub Actions macOS build (must pass before done).
- Bundled blocklists are a curated starter set, not full EasyList (EasyList-compatible
  files can be dropped into `Sources/BiTTU/Resources/blocklists/`).
- WKWebView content rule lists support a subset of content-blocker syntax.

## Phases

## Phase 1: Secure working browser core (this run)
Thin vertical slice: real tab UI ⇒ real page loads through the security policy ⇒
blocking layer active.
- [x] SPM package, .gitignore, PLAN.md
- [x] Browser window: toolbar (back/forward/reload/shield), tab bar (normal + private tabs)
- [x] Navigation: address bar resolves URLs vs DuckDuckGo search; Enter loads page
- [x] Security policy: only http/https allowed; http upgraded to https; other schemes cancelled
- [x] Permission gate: camera/mic/motion denied, popups blocked, JS dialogs handled
- [x] Content blocker: bundled rule lists compiled and attached to every tab
- [x] `scripts/make-app.sh` bundles `build/BiTTU.app`
- [ ] README with build/run instructions; CI macOS build green on GitHub
  <!-- Code + README done and verified (swiftc -parse, blocklist JSON valid, make-app.sh shellcheck).
         CI blocked: every Actions run is cancelled in ~1s by an account-level Actions billing/spend
         limit — fix at https://github.com/settings/billing, then re-run the "build" workflow. -->

Acceptance: `swift build` on macOS succeeds (CI green), app launches, loads sites,
blocks listed trackers, denies permissions, blocks popups.

## Phase 2: Everyday browsing polish
- [x] Bookmarks and history (local, exportable), downloads UI
- [x] Per-site shield toggle and counter of blocked requests
- [x] Custom search engines, reader mode
Acceptance: settings persist locally and per-site shields change blocking live.
Implementation: `UserData.swift` (bookmarks/history/engines as JSON in
~/Library/Application Support/BiTTU, ⌘D bookmark, exportable via save panel),
`Shields.swift` (per-host shield toggle, ⇧⌘S), `Downloads.swift` (WKDownloadDelegate
plus downloads panel, ⌥⌘L), `LibraryWindows.swift` (bookmarks/history/search-engine
windows), `ReaderMode.swift` (⇧⌘R extraction window). Non-downloadable MIME
responses hand off to the download manager; shields switching rebuilds the tab's
web view with or without the content-rule lists live.

## Phase 3: Brave-level privacy hardening
- [x] Ship full EasyList/EasyPrivacy lists, fingerprint-protection script injection
- [x] First-party isolation / cookie policy, HTTPS-only mode with warning page
Acceptance: privacy checks (e.g. Cover Your Tracks style tests) show hardened results.

## Phase 4: Distribution
- [ ] Signed & notarized build artifact from CI, Sparkle auto-update
Acceptance: downloadable .app opens on a clean Mac without Gatekeeper friction.