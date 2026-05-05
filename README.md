# npm remote control

A tiny, portable macOS app that turns the `scripts` in any `package.json` into a clickable floating panel — drop the `.app` next to a `package.json`, double-click, and you get one button per `npm run` script.

![platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![swift](https://img.shields.io/badge/Swift-5.9-orange)

## Install

1. Download `npm-remote-control.dmg` from the [latest release](#).
2. Open the DMG, drag **npm remote control** into your npm project folder (not `/Applications` — it reads `package.json` from wherever it lives).
3. Right-click → **Open** the first time to bypass Gatekeeper (ad-hoc signed, not notarized).

## Use

- **Click a script** → runs `npm run <name>`, button shows a spinner while it's running.
- **Running scripts** — the button is a no-op while a script is active (a Kill button is coming in the next update).
- **Refresh** — click ↺ in the header to re-read `package.json` without restarting the app.
- **Move the window** — drag anywhere on the panel.

The panel floats above other windows and stays on all Spaces.

## Build from source

Requires Xcode command-line tools and Node/npm on PATH.

```bash
git clone https://github.com/your-org/npm-remote-control
cd npm-remote-control

make app          # → build/release/npm-remote-control.app
make dmg          # → build/release/npm-remote-control.dmg

# Quick dev loop (reads package.json from current directory)
swift run
```

## How it works

1. On launch the app looks for `package.json` in the folder it lives in (falls back to the current working directory when running via `swift run`).
2. Parses the `scripts` block, preserving the exact insertion order from the file.
3. Renders one row per script in a small floating panel (280 px wide, max 600 px tall, scrollable).
4. Tapping a row spawns `npm run <name>` via `Process` — no shell, no injection risk.
5. Output is buffered per-script (capped at 5000 lines / 256 KB); an embedded terminal panel is coming in the next milestone.

## Requirements

- macOS 13 Ventura or later
- npm on PATH (Homebrew, nvm, fnm — anything that puts npm in `/usr/local/bin` or `/opt/homebrew/bin`)

## What's working / what's next

| Feature | Status |
|---|---|
| Reads `package.json`, shows scripts in order | ✅ |
| Floating borderless window, blur background | ✅ |
| Run scripts, show spinner / exit status | ✅ |
| `.app` bundle + drag-to-install DMG | ✅ |
| Embedded terminal panel (live output + Kill) | 🔜 M4 |
| Watch `package.json` for changes | 🔜 M6 |
| Persist window position per project | 🔜 M6 |

## License

MIT
