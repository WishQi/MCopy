#!/usr/bin/env bash
#
# Build, sign, notarize, and package MCopy for Developer ID distribution.
#
# Prerequisites (one-time setup):
#   1. Apple Developer Program membership; Team ID 9VPLXE5668.
#   2. "Developer ID Application: <Your Name> (9VPLXE5668)" certificate installed in your login keychain.
#      Xcode → Settings → Accounts → Manage Certificates → "+" Developer ID Application.
#   3. Notarization credentials stored in a keychain profile named "mcopy-notary":
#        xcrun notarytool store-credentials mcopy-notary \
#            --apple-id you@example.com \
#            --team-id 9VPLXE5668 \
#            --password <app-specific-password from appleid.apple.com>
#
# Usage:
#   scripts/release.sh                # builds, notarizes, staples, zips into ./build/
#

set -euo pipefail

SCHEME="MCopy"
PROJECT="MCopy.xcodeproj"
CONFIG="Release"
TEAM_ID="9VPLXE5668"
NOTARY_PROFILE="mcopy-notary"
APP_NAME="MCopy"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
EXPORT_PLIST="$BUILD_DIR/ExportOptions.plist"

cd "$ROOT"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

cat > "$EXPORT_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
EOF

echo "==> Archiving"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -destination "generic/platform=macOS" \
    -archivePath "$ARCHIVE_PATH" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    archive

echo "==> Exporting Developer ID-signed app"
xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_PLIST"

APP_PATH="$EXPORT_DIR/$(ls "$EXPORT_DIR" | grep '\.app$' | head -1)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
    echo "ERROR: exported .app not found in $EXPORT_DIR" >&2
    exit 1
fi
echo "    -> $APP_PATH"

ZIP_PATH="$BUILD_DIR/$APP_NAME.zip"
echo "==> Zipping for notarization"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "==> Submitting to notary service (this can take a few minutes)"
xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

echo "==> Stapling ticket"
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

echo "==> Re-zipping stapled app"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo
echo "Done."
echo "  App: $APP_PATH"
echo "  Zip: $ZIP_PATH"
echo
echo "Next: upload $ZIP_PATH to GitHub Releases."
