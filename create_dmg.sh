#!/bin/bash
# create_dmg.sh — builds the app and packages it as a DMG for distribution
# Usage: bash create_dmg.sh

set -e
cd "$(dirname "$0")"

APP_NAME="ytAnalyticsMenuBar"
VERSION="1.0"
DMG_NAME="YouTube-Analytics-${VERSION}.dmg"
BUILD_DIR="/tmp/ytAnalytics-build"
STAGING="/tmp/ytanalytics-dmg-staging"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Building YouTube Analytics v${VERSION}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Build ──────────────────────────────────────────────────────────────────────
echo "→ Building app…"
xcodebuild \
  -project xcode/ytAnalytics.xcodeproj \
  -scheme ytAnalyticsMenuBar \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -quiet

APP="$BUILD_DIR/Build/Products/Release/${APP_NAME}.app"
echo "✓  Built: $APP"

# ── Stage ──────────────────────────────────────────────────────────────────────
echo "→ Staging DMG contents…"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
xattr -rd com.apple.quarantine "$STAGING/${APP_NAME}.app" 2>/dev/null || true

# Symlink to /Applications for drag-install
ln -s /Applications "$STAGING/Applications"

echo "✓  Staged"

# ── Create DMG ─────────────────────────────────────────────────────────────────
echo "→ Creating DMG…"
rm -f "$DMG_NAME"
hdiutil create \
  -volname "YouTube Analytics" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG_NAME"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅  Done: $(pwd)/$DMG_NAME  ($(du -sh "$DMG_NAME" | cut -f1))"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Clean up staging
rm -rf "$STAGING"
