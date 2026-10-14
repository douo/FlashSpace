#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"

if [[ ! -f project.yml || ! -d FlashSpace || ! -d FlashSpaceCLI ]]; then
  echo "error: this script must run inside the FlashSpace repository" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: commit all release changes before packaging" >&2
  exit 1
fi

SIGNING_ENV="$HOME/.config/apple/signing.env"
if [[ ! -f "$SIGNING_ENV" ]]; then
  echo "error: missing user signing configuration: $SIGNING_ENV" >&2
  exit 1
fi
source "$SIGNING_ENV"
SIGNING_IDENTITY="${APPLE_CODE_SIGNING_IDENTITY:?missing fixed signing identity}"
SIGNING_KEYCHAIN="${APPLE_CODE_SIGNING_KEYCHAIN:?missing signing keychain}"
if [[ ! "$SIGNING_IDENTITY" =~ ^[[:xdigit:]]{40}$ ]]; then
  echo "error: the signing identity must be an explicit certificate SHA-1" >&2
  exit 1
fi
if ! security find-identity -v -p codesigning "$SIGNING_KEYCHAIN" | rg -Fq "$SIGNING_IDENTITY"; then
  echo "error: configured signing identity is unavailable in $SIGNING_KEYCHAIN" >&2
  exit 1
fi
SIGNING_REQUIREMENT="certificate leaf = H\"$SIGNING_IDENTITY\""

echo "==> Checking that CLI codesign patch is not in project.yml"
if rg -n "Sign the CLI tool|Signing FlashSpace CLI|codesign --force --sign" project.yml >/dev/null; then
  echo "error: project.yml contains CLI signing code; keep CLI signing in packaging, not project history" >&2
  exit 1
fi

echo "==> Generating Xcode project"
xcodegen generate

echo "==> Building Release with certificate $SIGNING_IDENTITY"
xcodebuild \
  -project FlashSpace.xcodeproj \
  -scheme FlashSpace \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  -disableAutomaticPackageResolution \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM='' \
  OTHER_CODE_SIGN_FLAGS='' \
  ENABLE_HARDENED_RUNTIME=NO \
  build

APP=".build/DerivedData/Build/Products/Release/FlashSpace.app"
if [[ ! -d "$APP" ]]; then
  echo "error: expected app not found: $APP" >&2
  exit 1
fi

echo "==> Verifying build before packaging signatures"
codesign --verify --deep --strict "$APP"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")"
OUT_DIR=".build/PersonalRelease"
ZIP="$OUT_DIR/FlashSpace-${VERSION}-local.zip"
ENTITLEMENTS=".build/PersonalRelease/flashspace-local.entitlements"

mkdir -p "$OUT_DIR"
cp FlashSpace/FlashSpace.entitlements "$ENTITLEMENTS"
/usr/libexec/PlistBuddy -c 'Add :com.apple.security.cs.disable-library-validation bool true' "$ENTITLEMENTS"

sign_item() {
  codesign --force --sign "$SIGNING_IDENTITY" --keychain "$SIGNING_KEYCHAIN" \
    --timestamp=none --options runtime "$@"
}

echo "==> Signing Sparkle nested components with the fixed certificate"
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/Current"
for item in \
  "$SPARKLE/XPCServices/Downloader.xpc" \
  "$SPARKLE/XPCServices/Installer.xpc" \
  "$SPARKLE/Updater.app" \
  "$SPARKLE/Autoupdate" \
  "$SPARKLE/Sparkle"; do
  sign_item "$item"
done
sign_item "$APP/Contents/Frameworks/Sparkle.framework"

echo "==> Signing bundled CLI with a stable identifier"
sign_item --identifier flashspace "$APP/Contents/Resources/flashspace"

echo "==> Signing app with hardened runtime and library-validation entitlement"
sign_item --entitlements "$ENTITLEMENTS" "$APP"

echo "==> Verifying signatures and certificate consistency"
codesign --verify --deep --strict --verbose=2 "$APP"
for item in \
  "$SPARKLE/XPCServices/Downloader.xpc" \
  "$SPARKLE/XPCServices/Installer.xpc" \
  "$SPARKLE/Updater.app" \
  "$SPARKLE/Autoupdate" \
  "$APP/Contents/Frameworks/Sparkle.framework" \
  "$APP/Contents/Resources/flashspace" \
  "$APP"; do
  codesign --verify --strict --all-architectures -R="$SIGNING_REQUIREMENT" "$item"
done
codesign -dr - "$APP" 2> "$OUT_DIR/FlashSpace-${VERSION}-designated-requirement.txt"

"$APP/Contents/Resources/flashspace" focus --help
"$APP/Contents/Resources/flashspace" list-workspaces --help

echo "==> Packaging zip"
ZIP_TEMP="$(mktemp "$OUT_DIR/.FlashSpace-${VERSION}.XXXXXX")"
trap 'rm -f "$ZIP_TEMP"' EXIT
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP_TEMP"
mv -f "$ZIP_TEMP" "$ZIP"

echo
echo "Release app: $APP"
echo "Release zip: $ZIP"
echo "Version: $VERSION ($BUILD)"
echo "SHA256:"
shasum -a 256 "$ZIP"
