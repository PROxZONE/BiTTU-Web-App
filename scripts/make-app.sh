#!/usr/bin/env bash
# Build BiTTU.app from the Swift package (macOS only).
set -euo pipefail
cd "$(dirname "$0")/.."

# Full EasyList/EasyPrivacy at build time: download the filter sources and
# compile them into WebKit content-blocker JSON chunks. The small bundled
# core list stays as the offline fallback if this step is skipped.
BLOCKLISTS="Sources/BiTTU/Resources/blocklists"
if command -v python3 >/dev/null && curl -sfL -o /tmp/bittu-easylist.txt https://easylist.to/easylist/easylist.txt \
   && curl -sfL -o /tmp/bittu-easyprivacy.txt https://easylist.to/easylist/easyprivacy.txt; then
    python3 scripts/build-blocklists.py /tmp/bittu-easylist.txt "$BLOCKLISTS/easylist.json"
    python3 scripts/build-blocklists.py /tmp/bittu-easyprivacy.txt "$BLOCKLISTS/easyprivacy.json"
else
    echo "make-app: could not fetch EasyList/EasyPrivacy — shipping bundled core list only"
fi

swift build -c release

APP="build/BiTTU.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp .build/release/BiTTU "$APP/Contents/MacOS/BiTTU"

# Sparkle comes in as a binary framework via SPM; embed it so the bundle is
# self-contained and the linker's @rpath reference resolves inside the .app.
SPARKLE_FW="$(find .build/release -maxdepth 1 -name 'Sparkle*.framework' | head -1 || true)"
if [ -n "$SPARKLE_FW" ]; then
    cp -R "$SPARKLE_FW" "$APP/Contents/Frameworks/"
    install_name_tool -add_rpath @executable_path/../Frameworks "$APP/Contents/MacOS/BiTTU" 2>/dev/null || true
else
    echo "make-app: Sparkle framework not found in .build/release — shipping without auto-update"
fi

# Update feed + EdDSA key: set in CI (BITTU_UPDATE_FEED / BITTU_EDDSA_PUBLIC_KEY).
# Without a feed the in-app updater stays disabled (AutoUpdate checks SUFeedURL).
UPDATE_FEED="${BITTU_UPDATE_FEED:-https://PROxZONE.github.io/BiTTU-Web-App/appcast.xml}"
EDDSA_KEY="${BITTU_EDDSA_PUBLIC_KEY:-}"
APP_VERSION="${BITTU_VERSION:-1.0.0}"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>BiTTU</string>
    <key>CFBundleDisplayName</key>     <string>BiTTU Web App</string>
    <key>CFBundleIdentifier</key>      <string>app.bittu.web</string>
    <key>CFBundleVersion</key>         <string>__BITTU_VERSION__</string>
    <key>CFBundleShortVersionString</key><string>__BITTU_VERSION__</string>
    <key>CFBundleExecutable</key>      <string>BiTTU</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <key>NSHighResolutionCapable</key> <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key><false/>
    </dict>
    <key>SUFeedURL</key>
    <string>__BITTU_UPDATE_FEED__</string>
    <key>SUPublicEDKey</key>
    <string>__BITTU_EDDSA_PUBLIC_KEY__</string>
</dict>
</plist>
PLIST

# Substitute the two update keys without letting heredoc expansion touch XML.
python3 - "$APP/Contents/Info.plist" "$UPDATE_FEED" "$EDDSA_KEY" "$APP_VERSION" <<'PY'
import sys
path, feed, key, version = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(path, encoding="utf-8") as fh:
    text = fh.read()
text = text.replace("__BITTU_UPDATE_FEED__", feed).replace("__BITTU_EDDSA_PUBLIC_KEY__", key)
text = text.replace("__BITTU_VERSION__", version)
with open(path, "w", encoding="utf-8") as fh:
    fh.write(text)
PY

# Developer ID signing (CI): BITTU_CODESIGN_IDENTITY="Developer ID Application: …".
# Falls back to ad-hoc so a dev build on any Mac still runs.
IDENTITY="${BITTU_CODESIGN_IDENTITY:--}"
if [ -n "$SPARKLE_FW" ]; then
    codesign --force --options runtime --sign "$IDENTITY" "$APP/Contents/Frameworks/Sparkle.framework" || true
fi
codesign --force --options runtime --sign "$IDENTITY" "$APP" 2>/dev/null || \
    codesign --force --sign - "$APP"
echo "Built $APP — open it with: open $APP"