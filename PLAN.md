# Implementation plan

This is the plan Claude Code should follow. Work top-down. Commit after each milestone.

## Milestone 0 — Project skeleton

- Create a Swift Package Manager executable target named `NpmRemoteControl`.
- Use `swift-tools-version:5.9` minimum.
- Set up `Package.swift` with macOS 13+ as the deployment target (SwiftUI features used freely).
- Add a `.gitignore` for Swift / Xcode (`.build/`, `*.xcodeproj/`, `DerivedData/`, `.DS_Store`). Already committed.
- Add a `Makefile` (or `build.sh`) with these targets:
  - `build` — `swift build -c release`
  - `app` — wraps the binary into a `.app` bundle (see Bundle section below)
  - `clean`
- Verify `swift build` succeeds with a stub `main.swift` that just prints "hello".

## Milestone 1 — package.json discovery + parsing

- On launch, find `package.json` using this resolution order:
  1. `Bundle.main.bundleURL.deletingLastPathComponent()` — the directory containing the `.app`. **This is the primary case.**
  2. `FileManager.default.currentDirectoryPath` — for CLI / dev usage via `swift run`.
  3. If neither has a `package.json`, show an empty state: "No package.json found next to this app. Drop the app into an npm project folder."
- Parse the JSON with `JSONDecoder` into a struct that has `name`, `scripts: [String: String]`.
- Preserve script ordering as it appears in the file (use a custom decoder or read raw JSON to get insertion order — `JSONDecoder` into `[String:String]` does NOT preserve order; we need order).

## Milestone 2 — UI: the button list

- Use SwiftUI. Single window, no title bar (`NSWindow.styleMask` = `[.borderless, .resizable]`), background blur (NSVisualEffectView), corner radius 12.
- Width fixed at 280, height grows with content (max 600, scrollable beyond).
- For each script, render a `ScriptRow` view:
  - Left: script name (monospace, ~13pt).
  - Right: small icon — play / spinner / stop depending on state.
  - Tap target: whole row.
- Show project name (from `package.json`) + a small refresh icon in the header.
- Window is draggable from the header.
- Click outside the window? Don't dismiss — this is a tool window, not a popover.

## Milestone 3 — Running scripts

- Build a `ScriptRunner` actor that owns a process map: `[scriptName: Process]`.
- `run(scriptName:)`:
  - Resolve `npm` via `/usr/bin/env`. Use `Process` with `executableURL = /usr/bin/env`, args `["npm", "run", scriptName]`.
  - Set `currentDirectoryURL` to the package.json folder.
  - Set `environment` to inherit + ensure `PATH` includes `/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin`.
  - Wire up a `Pipe` for stdout and stderr → write into a per-script `OutputBuffer`.
  - On `terminationHandler`, post a notification with exit code; runner removes from process map.
- `kill(scriptName:)`: send SIGTERM. After 3s, escalate to SIGKILL if still alive.

## Milestone 4 — Embedded terminal panel

- Tapping a script row that's running expands an inline terminal panel under the row.
- Panel: monospace text view, dark background, ~200pt tall, scrollable, auto-scrolls to bottom.
- Top-right of panel: a small Kill (×) button.
- ANSI handling: strip ANSI escapes for v1 (don't try to colorize). Track this as a follow-up.
- Buffer is capped (e.g., last 5000 lines or 256 KB) to keep memory bounded.
- On clean exit (code 0): collapse the panel after 1.5s.
- On non-zero exit: keep panel open, show exit code in red at the bottom.

## Milestone 5 — Bundling as a .app

- After `swift build -c release`, package as an .app:
  ```
  AppName.app/
    Contents/
      Info.plist        (CFBundleIdentifier, LSUIElement=YES if we want a menubar-only app, etc.)
      MacOS/
        NpmRemoteControl   (the binary)
      Resources/
        AppIcon.icns
  ```
- `LSUIElement = YES` keeps it out of the Dock — but this is a regular app, so leave it NO for v1.
- Set `CFBundleName = "npm remote control"`.
- Codesign with ad-hoc signature (`codesign --force --deep --sign - AppName.app`) so it launches without Gatekeeper griping (user will still need to right-click → Open the first time on a fresh download).

## Milestone 6 — Polish

- Persist window position per project (use the package.json's resolved path as a key in `UserDefaults`).
- Handle package.json edits: `DispatchSource.makeFileSystemObjectSource` to watch the file; reload on change.
- Empty-state and error states (malformed package.json, no scripts).
- About / version footer.

## Out of scope (for v1)

- Workspaces / monorepos — only top-level `package.json`.
- pnpm / yarn detection — npm only for v1.
- ANSI color in embedded terminal.
- Auto-updates.
- Notarization / Apple Developer account signing.

## Testing checklist

- Drop `.app` next to a Vite project, click `dev` — server starts, terminal shows logs, Kill stops it.
- Click `format` — quick task, terminal flashes briefly, auto-collapses on exit 0.
- Click `test` (failing) — terminal stays open, exit code shown.
- Click `dev` twice — second click is a no-op while running.
- Move `.app` to a folder with no `package.json` — empty state.
- Edit `package.json` to add a new script — UI updates within ~1s.
