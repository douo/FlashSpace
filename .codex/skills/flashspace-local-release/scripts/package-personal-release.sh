#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"

if [[ ! -f project.yml || ! -d FlashSpace || ! -d FlashSpaceCLI ]]; then
  echo "error: this script must run inside the FlashSpace repository" >&2
  exit 1
fi

echo "==> Checking that CLI codesign patch is not in project.yml"
if rg -n "Sign the CLI tool|Signing FlashSpace CLI|codesign --force --sign" project.yml >/dev/null; then
  echo "error: project.yml contains CLI signing code; keep CLI signing in packaging, not project history" >&2
  exit 1
fi

echo "==> Generating Xcode project"
xcodegen generate

echo "==> Building Release with local ad-hoc signing"
xcodebuild \
  -project FlashSpace.xcodeproj \
  -scheme FlashSpace \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGN_IDENTITY='-' \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM='' \
  build

APP=".build/DerivedData/Build/Products/Release/FlashSpace.app"
if [[ ! -d "$APP" ]]; then
  echo "error: expected app not found: $APP" >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")"
OUT_DIR=".build/PersonalRelease"
ZIP="$OUT_DIR/FlashSpace-${VERSION}-local.zip"
ENTITLEMENTS=".build/PersonalRelease/flashspace-local.entitlements"

mkdir -p "$OUT_DIR"
cat > "$ENTITLEMENTS" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.cs.disable-library-validation</key>
  <true/>
</dict>
</plist>
PLIST

echo "==> Re-signing Sparkle nested components ad-hoc with hardened runtime"
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
for item in \
  "$SPARKLE/XPCServices/Downloader.xpc" \
  "$SPARKLE/XPCServices/Installer.xpc" \
  "$SPARKLE/Updater.app" \
  "$SPARKLE/Autoupdate" \
  "$SPARKLE/Sparkle"; do
  if [[ -e "$item" ]]; then
    codesign --force --sign - --options runtime "$item"
  fi
done
codesign --force --sign - --options runtime "$APP/Contents/Frameworks/Sparkle.framework"

echo "==> Signing bundled CLI ad-hoc with hardened runtime"
codesign --force --sign - --options runtime "$APP/Contents/Resources/flashspace"

echo "==> Re-signing app ad-hoc with hardened runtime"
codesign --force --sign - --options runtime --entitlements "$ENTITLEMENTS" "$APP"

echo "==> Verifying app signature"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> Packaging zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo
echo "Release app: $APP"
echo "Release zip: $ZIP"
echo "Version: $VERSION ($BUILD)"
echo "SHA256:"
shasum -a 256 "$ZIP"
