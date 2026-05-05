# Architecture

## File layout

```
npm-remote-control/
  Package.swift
  Sources/
    NpmRemoteControl/
      main.swift                # @main entry
      App/
        NpmRemoteControlApp.swift
        ContentView.swift
      Model/
        PackageJSON.swift       # decode + ordered scripts
        Script.swift
      Runner/
        ScriptRunner.swift      # actor, owns Process map
        OutputBuffer.swift      # ring buffer of stdout/stderr lines
        ANSI.swift              # strip-only for v1
      Views/
        ScriptRow.swift
        TerminalPanel.swift
        HeaderView.swift
        BorderlessWindow.swift  # NSWindow subclass
      Util/
        ProjectLocator.swift    # find package.json
        Shell.swift             # PATH helpers
  Resources/
    AppIcon.icns                # placeholder
  Scripts/
    build-app.sh                # wrap binary into .app
  Makefile
  README.md
  PLAN.md
  ARCHITECTURE.md
  CLAUDE.md
  .gitignore
```

## Key types (sketch)

```swift
struct PackageJSON: Decodable {
    let name: String?
    let scripts: [Script]   // ordered
}

struct Script: Identifiable, Hashable {
    let id: String          // script name
    let command: String     // raw command string from package.json
}

enum ScriptState {
    case idle
    case running(pid: Int32, startedAt: Date)
    case exited(code: Int32, at: Date)
}

@MainActor
final class AppState: ObservableObject {
    @Published var project: PackageJSON?
    @Published var states: [String: ScriptState] = [:]
    @Published var outputs: [String: OutputBuffer] = [:]
    @Published var expanded: Set<String> = []
    let runner = ScriptRunner()
}

actor ScriptRunner {
    private var processes: [String: Process] = [:]
    func run(_ name: String, in dir: URL, onOutput: @escaping (String) -> Void, onExit: @escaping (Int32) -> Void) async throws
    func kill(_ name: String) async
}
```

## Why these choices

- **SwiftUI** — smallest native UI surface, no AppKit boilerplate for the basic layout. We drop into AppKit only for the borderless/blurred window.
- **Process + Pipe** — Foundation gives us everything we need to spawn `npm run` and stream output. No external deps.
- **No Combine for IO** — use `AsyncStream` from the pipe's `readabilityHandler` to keep the model simple.
- **Ordered scripts** — `JSONDecoder` into `[String:String]` does not preserve order. Two viable approaches: (a) parse with `JSONSerialization` then re-walk the raw bytes to recover key order, or (b) write a custom `Decodable` that uses `KeyedDecodingContainer.allKeys` (whose order is implementation-defined but in practice is insertion order). Pick (a) for determinism.

## Binary size

Target < 5 MB:
- Build with `-c release`.
- Strip symbols: `strip -S`.
- No third-party dependencies.
- SwiftUI + Foundation are dynamically linked from the OS, not embedded.

## Sandboxing / entitlements

- v1 is unsandboxed (no `.entitlements`). The user is dropping it into their own project folders; we need full file + process access.
- Future: if we want to ship via the Mac App Store, we'd need a sandbox + a different process-spawning strategy. Out of scope.
