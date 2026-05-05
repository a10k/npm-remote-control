#!/usr/bin/env bash
set -euo pipefail

APP="$1"      # e.g. build/release/npm-remote-control.app
DMG="$2"      # e.g. build/release/npm-remote-control.dmg

STAGING="$(mktemp -d)/dmg-staging"
mkdir -p "$STAGING"

cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"
hdiutil create \
    -volname "npm remote control" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG"

rm -rf "$(dirname "$STAGING")"
echo "Built: $DMG"
