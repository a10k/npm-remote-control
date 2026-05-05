# Architecture

## File layout

```
npm-remote-control/
  Package.swift
  Makefile
  Sources/
    NpmRemoteControl/
      main.swift                  # NSApplication entry point
      App/
        NpmRemoteControlApp.swift # AppState + AppDelegate
        ContentView.swift
      Model/
        PackageJSON.swift         # Script, ScriptState, PackageJSON + parser
      Runner/
        ScriptRunner.swift        # actor — owns Process map
        OutputBuffer.swift        # 5000-line / 256 KB ring buffer
        ANSI.swift                # escape-sequence stripper
      Views/
        ScriptRow.swift
        TerminalPanel.swift       # M4 — not yet implemented
        HeaderView.swift
        BorderlessWindow.swift    # NSWindow subclass
      Util/
        ProjectLocator.swift      # package.json discovery
        Shell.swift               # PATH enrichment
  Resources/
    AppIcon.icns                  # placeholder
  Scripts/
    build-app.sh                  # wrap binary → .app bundle
    build-dmg.sh                  # wrap .app → drag-to-install DMG
  README.md
  PLAN.md
  ARCHITECTURE.md
  CLAUDE.md
  .gitignore
```

## Key types

```swift
struct Script: Identifiable, Hashable {
    let id: String      // script name (key in package.json)
    let command: String // raw command string
}

struct PackageJSON {
    let name: String?
    let scripts: [Script] // ordered as they appear in the file
}

enum ScriptState: Equatable {
    case idle
    case running(pid: Int32, startedAt: Date)
    case exited(code: Int32, at: Date)
}

final class AppState: ObservableObject, @unchecked Sendable {
    @Published var project: PackageJSON?
    @Published var states: [String: ScriptState]
    @Published var outputs: [String: OutputBuffer]  // mutated in place; objectWillChange sent manually
    @Published var expanded: Set<String>
    let runner = ScriptRunner()
}

actor ScriptRunner {
    private var processes: [String: Process]
    func run(_ name: String, in dir: URL,
             onOutput: @escaping (String) -> Void,
             onExit: @escaping (Int32) -> Void) throws -> Int32
    func terminate(_ name: String) async  // SIGTERM → SIGKILL after 3 s
}
```

## Design decisions

**SwiftUI + AppKit seam** — SwiftUI handles the view hierarchy. AppKit is used only for `BorderlessWindow` (NSWindow subclass) and `NSVisualEffectView` for the behind-window blur. The hosting view is an `NSHostingView` embedded inside the visual effect view.

**Process + Pipe** — `Process` with `/usr/bin/env` as the executable avoids shell-injection risk and makes PATH resolution explicit. stdout and stderr share one `OutputBuffer` per script via `readabilityHandler`.

**Ordered scripts** — `JSONSerialization` produces an unordered `NSDictionary`. `PackageJSON.parse(from:)` re-walks the raw UTF-8 bytes to recover key insertion order before building the `[Script]` array.

**OutputBuffer** — a plain class, not `ObservableObject`. `AppState` calls `objectWillChange.send()` manually before each `append` so SwiftUI re-renders the terminal panel (M4).

**PATH enrichment** — `Shell.enrichedPath` prepends `/usr/local/bin` and `/opt/homebrew/bin` if not already present. This is the minimum needed to find npm installed via Homebrew or nvm's shims on a typical developer machine.

**Window sizing** — `AppDelegate` observes `AppState.$project` and calls `NSHostingView.fittingSize` after a 50 ms defer to let SwiftUI settle. Height is clamped to 80–600 px.

## Binary size

Release binary is currently ~320 KB (stripped). SwiftUI and Foundation are dynamically linked from the OS. No third-party packages.

## Sandboxing

v1 is unsandboxed — the app needs full file access (to read arbitrary `package.json` paths) and process access (to spawn `npm`). Mac App Store distribution would require sandboxing and a different spawn strategy; that's out of scope.
