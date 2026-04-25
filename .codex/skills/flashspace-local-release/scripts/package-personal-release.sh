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

echo "==> Signing bundled CLI ad-hoc with hardened runtime"
codesign --force --sign - --options runtime "$APP/Contents/Resources/flashspace"

echo "==> Re-signing app ad-hoc with hardened runtime"
codesign --force --deep --sign - --options runtime "$APP"

echo "==> Verifying app signature"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> Packaging zip"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo
echo "Release app: $APP"
echo "Release zip: $ZIP"
echo "Version: $VERSION ($BUILD)"
echo "SHA256:"
shasum -a 256 "$ZIP"
