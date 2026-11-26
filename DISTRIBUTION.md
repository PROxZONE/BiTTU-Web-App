# Distributing BiTTU (Phase 4)

CI (`.github/workflows/build.yml`, `macos-14`) produces a signed, notarized DMG on
every push to `main` and publishes a Sparkle appcast so installed copies update
in place.

## One-time setup (repo settings → Secrets and variables → Actions)

| Secret | Purpose |
| --- | --- |
| `APPLE_CERT_P12_BASE64` | Developer ID Application certificate (.p12, base64) |
| `APPLE_CERT_PASSWORD` | password for the .p12 |
| `APPLE_CODESIGN_IDENTITY` | e.g. `Developer ID Application: Your Name (TEAMID)` |
| `APPLE_NOTARY_ID` / `APPLE_NOTARY_PASSWORD` / `APPLE_NOTARY_TEAM_ID` | App Store Connect credentials for `notarytool` |
| `SPARKLE_EDDSA_KEY` | private EdDSA key from `sign_update -p` (signs the DMG) |
| var `SPARKLE_EDDSA_PUBLIC_KEY` | matching `SUPublicEDKey` baked into Info.plist |

Without these secrets the workflow still builds and uploads an ad-hoc-signed
DMG; the in-app updater stays disabled (no EdDSA key) and Gatekeeper will show
a right-click-to-open prompt instead of nothing.

## What CI does

1. `swift build` (debug + release).
2. `scripts/make-app.sh` — bundles `BiTTU.app`, embeds the Sparkle framework,
   sets `SUFeedURL`/`SUPublicEDKey`/version, codesigns with the Developer ID
   (or ad-hoc `-` in dev).
3. Builds `BiTTU-Web-App.dmg`, notarizes with `notarytool --wait`, staples,
   validates.
4. Uploads artifacts on every run; on `main` attaches the DMG to a
   `v0.<run>.0` GitHub release.
5. Signs the DMG with `sign_update` and regenerates `appcast.xml` on the
   `gh-pages` branch (served at `https://PROxZONE.github.io/BiTTU-Web-App/appcast.xml`).

## Local build (any Mac)

```sh
./scripts/make-app.sh          # ad-hoc signed, updater disabled
BITTU_CODESIGN_IDENTITY="Developer ID Application: …" \
BITTU_EDDSA_PUBLIC_KEY="…" \
BITTU_VERSION="1.0.1" ./scripts/make-app.sh
```