# CLAUDE.md

Context for Claude Code when working in this repo.

## What this project is

`npm-remote-control` is a tiny native macOS app (Swift + SwiftUI) that the user drops into any npm project folder. It reads `package.json`, shows one button per script, and runs them on click. Long-running scripts show an inline embedded terminal with a Kill button.

## Hard constraints

- **macOS only.** Don't add Linux/Windows fallbacks.
- **Swift + SwiftUI only.** No Electron, no webview, no third-party Swift packages without asking.
- **Minimal code, minimal binary.** Target < 5 MB release binary. Every dependency must justify its weight.
- **No tests required for v1**, but if you add them keep them in `Tests/NpmRemoteControlTests/`.
- **Single binary, portable .app bundle.** It must work when dropped into an arbitrary npm project folder, with no installer and no PATH setup.

## Working style

- Prefer 1 file with 200 lines over 5 files with 40 lines each, unless the boundary is genuinely meaningful.
- No comments that just restate the code. Comments should explain *why*, not *what*.
- Do not add `Co-Authored-By` or similar signatures to commit messages.

## Build & run

```bash
# Quick iteration
swift run

# Release build
make build

# Wrap into .app
make app
# → outputs build/release/npm-remote-control.app
```

To test in-place: copy `npm-remote-control.app` into an existing npm project folder (one that has a `package.json` with a `scripts` block) and double-click.

## Useful test projects

Any Vite, Next.js, or Create React App project will do — they all have `dev`, `build`, and similar scripts. If you need a throwaway one:

```bash
mkdir /tmp/test-npm-rc && cd /tmp/test-npm-rc
npm init -y
# add some scripts to package.json
```

## Things to NOT do

- Don't add a settings UI. Zero config is the point.
- Don't add yarn/pnpm support yet.
- Don't try to parse `package.json` with regex. Use `JSONDecoder` or `JSONSerialization`.
- Don't shell out via `/bin/sh -c "npm run ..."` — use `Process` with explicit executable + args. Avoid shell injection and PATH surprises.
