# Implementation plan

Work top-down. Commit after each milestone.

## ✅ Milestone 0 — Project skeleton

- Swift Package Manager executable target `NpmRemoteControl`, swift-tools-version 5.9, macOS 13+.
- `Makefile` with `build`, `app`, `dmg`, `clean` targets.
- `Scripts/build-app.sh` wraps the release binary into a `.app` bundle.

## ✅ Milestone 1 — package.json discovery + parsing

- `ProjectLocator` checks the `.app`'s parent directory first, falls back to CWD (`swift run`).
- `PackageJSON.parse(from:)` uses `JSONSerialization` for values and re-walks raw UTF-8 bytes to recover key insertion order (dictionaries are unordered).
- Empty-state message when no `package.json` is found.

## ✅ Milestone 2 — UI: the button list

- `BorderlessWindow`: `styleMask = [.borderless, .resizable]`, `level = .floating`, `NSVisualEffectView(.sidebar)` for behind-window blur, corner radius 12, draggable anywhere.
- `ContentView` → `HeaderView` (project name + reload button) + scrollable `ScriptRow` list.
- `ScriptRow` shows script name (monospace 13pt) and a play / spinner / checkmark / ✗ icon driven by `ScriptState`.
- Window auto-sizes to content via `NSHostingView.fittingSize`, capped at 600 px.

## ✅ Milestone 3 — Running scripts

- `ScriptRunner` actor owns `[String: Process]`.
- Launches via `/usr/bin/env ["npm", "run", name]`; inherits env with `/usr/local/bin` and `/opt/homebrew/bin` prepended to PATH.
- Streams stdout + stderr through `readabilityHandler` → `OutputBuffer` (5000-line / 256 KB ring buffer).
- `terminate()` sends SIGTERM; escalates to SIGKILL via `Darwin.kill` after 3 s.
- `AppState.run(script:)` sets state optimistically, gets real PID after launch.

## ✅ Milestone 5 (partial) — Distribution

- `make app` → `build/release/npm-remote-control.app` with `Info.plist` and ad-hoc codesign.
- `make dmg` → `build/release/npm-remote-control.dmg` (drag-to-install, `.app` + `/Applications` symlink).

## 🔜 Milestone 4 — Embedded terminal panel

- Tapping a running script row expands an inline terminal panel below the row.
- Monospace text, dark background, ~200 pt tall, auto-scrolls, Kill (×) button top-right.
- On exit 0: auto-collapse after 1.5 s. On non-zero: keep open, show exit code in red.

## 🔜 Milestone 5 (remainder) — App icon

- Add `AppIcon.icns` to `Resources/` and reference it in `Info.plist`.

## 🔜 Milestone 6 — Polish

- Persist window position per project (`UserDefaults`, keyed by resolved `package.json` path).
- Watch `package.json` with `DispatchSource.makeFileSystemObjectSource`; reload on change.
- Malformed JSON error state.
- About / version footer.

## Out of scope (v1)

- Workspaces / monorepos.
- pnpm / yarn support.
- ANSI color in terminal.
- Auto-updates.
- Notarization / App Store signing.

## Manual test checklist

- Drop `.app` next to a Vite project → click `dev`, server starts, spinner shows, Kill stops it.
- Click `format` → spinner then green checkmark, terminal auto-collapses (M4).
- Click `test` on a failing suite → terminal stays open with red exit code (M4).
- Click `dev` twice → second click is a no-op.
- Move `.app` to a folder with no `package.json` → empty-state message.
- Edit `package.json`, click ↺ → new scripts appear instantly.
