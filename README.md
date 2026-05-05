# npm-remote-control

A tiny, portable macOS app that turns the `scripts` in any `package.json` into a clickable widget — drop the `.app` next to a `package.json`, double-click, and you get a small floating panel of buttons for `npm run dev`, `build`, `test`, `format`, etc.

## Goals

- **Single-binary, portable**: a self-contained `.app` bundle the user can drop into any npm project folder.
- **Zero config**: reads `package.json` from the folder it lives in. No setup.
- **Tiny**: target binary size < 5 MB.
- **Native macOS**: Swift + SwiftUI, no Electron, no webview.
- **Minimal UI**: a small floating panel (~280×N px). One button per script. No chrome, no menus.

## How it works

1. App launches, locates `package.json` in its containing directory.
2. Parses `scripts` field, renders one button per script name.
3. Click a button → spawns `npm run <name>` as a child process.
4. If the script produces output (server logs, watcher), an inline embedded terminal slides open showing live stdout/stderr, with a **Kill** button in the top-right.
5. Clicking the same button again while it's running has no effect (button shows "running"). Clicking **Kill** terminates the process.
6. If the process exits cleanly (exit code 0), the embedded terminal auto-collapses after a short delay.
7. If it exits with an error, the terminal stays open showing the failure.

## Status

Planning. See `PLAN.md` and `ARCHITECTURE.md`.
