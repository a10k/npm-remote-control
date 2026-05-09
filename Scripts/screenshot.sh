#!/usr/bin/env bash
# macOS only. Launches the app against a sample vite project, starts the dev
# script, and captures the window to screenshot.png at the repo root.
#
# Requires Accessibility access for Terminal to simulate the click:
#   System Settings → Privacy & Security → Accessibility → add Terminal
set -euo pipefail

APP="${1:-build/release/npm-remote-control.app}"
OUT="$(pwd)/screenshot.png"

if [ ! -d "$APP" ]; then
    echo "error: app not found at $APP — run 'make app' first" >&2
    exit 1
fi

# ── Build sample project ──────────────────────────────────────────────────────
PROJ=/tmp/npm-rc-screenshot
rm -rf "$PROJ"
mkdir -p "$PROJ"

cat > "$PROJ/package.json" <<'JSON'
{
  "name": "your-vite-project",
  "version": "0.0.0",
  "scripts": {
    "dev": "sleep 300",
    "build": "vite build",
    "preview": "vite preview",
    "lint": "eslint . --ext js,jsx --report-unused-disable-directives --max-warnings 0",
    "format": "prettier --write ."
  }
}
JSON

cp -r "$APP" "$PROJ/npm-remote-control.app"

# ── Launch ────────────────────────────────────────────────────────────────────
pkill -x NpmRemoteControl 2>/dev/null || true
sleep 0.5

open "$PROJ/npm-remote-control.app"
sleep 3

# ── Start the dev script ──────────────────────────────────────────────────────
# Click the centre of the first row: titlebar (~28pt) + top padding (8pt)
# + half row height (~14pt) = ~50pt below the window's top edge.
if ! osascript <<'AS' 2>/dev/null; then
tell application "System Events"
    tell process "npm remote control"
        set frontmost to true
        delay 0.5
        set w to window 1
        set p to position of w
        set s to size of w
        set cx to (item 1 of p) + ((item 1 of s) / 2)
        set cy to (item 2 of p) + 50
        click at {cx as integer, cy as integer}
        delay 2
    end tell
end tell
AS
    echo >&2
    echo "error: could not simulate click — Terminal needs Accessibility access." >&2
    echo "  System Settings → Privacy & Security → Accessibility → add Terminal" >&2
    echo >&2
    pkill -x NpmRemoteControl 2>/dev/null || true
    exit 1
fi

# ── Capture via CGWindowListCreateImage ──────────────────────────────────────
# Write swift capture script to a temp file to keep argument passing simple.
SWIFTFILE=$(mktemp /tmp/cap-XXXXXX.swift)
trap 'rm -f "$SWIFTFILE"' EXIT

cat > "$SWIFTFILE" <<'SWIFT'
import CoreGraphics
import Foundation

guard CommandLine.arguments.count > 1 else { exit(1) }
let outPath = CommandLine.arguments[1]

guard let raw = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
    fputs("error: could not list windows\n", stderr); exit(1)
}
for w in raw {
    guard (w["kCGWindowOwnerName"] as? String) == "npm remote control",
          let n = w["kCGWindowNumber"] as? Int,
          let img = CGWindowListCreateImage(
              .null, .optionIncludingWindow, CGWindowID(n), .bestResolution
          ) else { continue }
    let data = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else { continue }
    CGImageDestinationAddImage(dest, img, nil)
    guard CGImageDestinationFinalize(dest) else { continue }
    do {
        try data.write(to: URL(fileURLWithPath: outPath), options: .atomic)
        exit(0)
    } catch {
        fputs("error: \(error)\n", stderr); exit(1)
    }
}
fputs("error: window not found\n", stderr)
exit(1)
SWIFT

swift "$SWIFTFILE" "$OUT"

# ── Cleanup ───────────────────────────────────────────────────────────────────
pkill -x NpmRemoteControl 2>/dev/null || true

echo "saved: screenshot.png"
