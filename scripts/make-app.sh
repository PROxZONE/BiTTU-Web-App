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
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/BiTTU "$APP/Contents/MacOS/BiTTU"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>BiTTU</string>
    <key>CFBundleDisplayName</key>     <string>BiTTU Web App</string>
    <key>CFBundleIdentifier</key>      <string>app.bittu.web</string>
    <key>CFBundleVersion</key>         <string>1.0.0</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleExecutable</key>      <string>BiTTU</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <key>NSHighResolutionCapable</key> <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key><false/>
    </dict>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" 2>/dev/null || true
echo "Built $APP — open it with: open $APP"