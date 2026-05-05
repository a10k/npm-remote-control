#!/usr/bin/env bash
set -euo pipefail

BINARY="$1"
APP="$2"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BINARY" "$APP/Contents/MacOS/NpmRemoteControl"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.npmremotecontrol.app</string>
    <key>CFBundleName</key>
    <string>npm remote control</string>
    <key>CFBundleExecutable</key>
    <string>NpmRemoteControl</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

strip -S "$APP/Contents/MacOS/NpmRemoteControl" 2>/dev/null || true
codesign --force --deep --sign - "$APP" 2>/dev/null || true

echo "Built: $APP"
