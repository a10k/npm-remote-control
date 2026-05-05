import AppKit
import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var project: PackageJSON?
    @Published var projectDirectory: URL?
    @Published var loadError: String?
    @Published var states: [String: ScriptState] = [:]
    @Published var expanded: Set<String> = []
    // Mutated in place; callers send objectWillChange manually.
    @Published var outputs: [String: OutputBuffer] = [:]

    private var userStopped: Set<String> = []
    let runner = ScriptRunner()
    private let fileWatcher = FileWatcher()

    // MARK: - Project loading

    func load() {
        guard let located = ProjectLocator.findPackageJSON() else {
            project = nil
            projectDirectory = nil
            loadError = nil
            return
        }
        projectDirectory = located.directory
        reloadFile(from: located.file)
        fileWatcher.watch(located.file) { [weak self] in self?.softReload() }
    }

    /// Full reload triggered by the ↺ button: kills processes and resets UI state.
    func reload() {
        guard let dir = projectDirectory else { load(); return }
        Task { await runner.terminateAll() }
        states = [:]
        outputs = [:]
        expanded = []
        userStopped = []
        reloadFile(from: dir.appendingPathComponent("package.json"))
    }

    /// Soft reload triggered by the file watcher: updates the script list only.
    private func softReload() {
        guard let dir = projectDirectory else { return }
        reloadFile(from: dir.appendingPathComponent("package.json"))
    }

    private func reloadFile(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            project = try PackageJSON.parse(from: data)
            loadError = nil
        } catch {
            project = nil
            loadError = error.localizedDescription
        }
    }

    // MARK: - Script lifecycle

    func run(script: Script) {
        guard let dir = projectDirectory else { return }
        let name = script.id
        if case .running = states[name] { return }

        let startTime = Date()
        outputs[name] = OutputBuffer()
        states[name] = .running(pid: -1, startedAt: startTime)
        expanded.insert(name)

        Task { [weak self] in
            guard let self else { return }
            do {
                let pid = try await self.runner.run(
                    name, in: dir,
                    onOutput: { [weak self] chunk in
                        DispatchQueue.main.async { self?.appendOutput(chunk, for: name) }
                    },
                    onExit: { [weak self] code in
                        DispatchQueue.main.async { [weak self] in
                            guard let self else { return }
                            // Ignore if the state was cleared by a reload.
                            guard case .running = self.states[name] else { return }
                            if self.userStopped.remove(name) != nil {
                                // User explicitly stopped — go back to idle with no badge.
                                self.states[name] = .idle
                            } else {
                                self.states[name] = .exited(code: code, at: Date())
                                if code == 0 {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        self.expanded.remove(name)
                                    }
                                }
                            }
                        }
                    }
                )
                DispatchQueue.main.async { [weak self] in
                    self?.states[name] = .running(pid: pid, startedAt: startTime)
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.outputs[name]?.append(
                        "Error: could not start npm — check that npm is in your PATH.\n" +
                        "\(error.localizedDescription)\n"
                    )
                    self.objectWillChange.send()
                    self.states[name] = .exited(code: 1, at: Date())
                }
            }
        }
    }

    func reset(scriptNamed name: String) {
        states[name] = .idle
        outputs[name]?.clear()
        objectWillChange.send()
        expanded.remove(name)
    }

    func stop(scriptNamed name: String) {
        userStopped.insert(name)
        outputs[name]?.clear()
        objectWillChange.send()
        expanded.remove(name)
        Task { await runner.terminate(name) }
    }

    private func appendOutput(_ chunk: String, for name: String) {
        guard let buffer = outputs[name] else { return }
        let normalized = chunk
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        objectWillChange.send()
        buffer.append(ANSI.strip(normalized))
    }
}

// MARK: - App delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: BorderlessWindow?
    let appState = AppState()
    private var cancellables = Set<AnyCancellable>()
    private var fittingHeight: (() -> CGFloat)?
    private var positionRestored = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()
        appState.load()

        let win = BorderlessWindow()
        win.delegate = self

        let hv = NSHostingView(rootView: ContentView().environmentObject(appState))
        win.contentView = hv
        fittingHeight = { hv.fittingSize.height }
        window = win

        // Resize on project change; restore saved position on the very first load.
        appState.$project
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    guard let self else { return }
                    self.sizeWindowToContent()
                    if !self.positionRestored {
                        self.positionRestored = true
                        self.restoreWindowPosition()
                    }
                }
            }
            .store(in: &cancellables)

        // Resize when terminal panels expand or collapse.
        appState.$expanded
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self?.sizeWindowToContent()
                }
            }
            .store(in: &cancellables)

        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { await appState.runner.terminateAll() }
        Thread.sleep(forTimeInterval: 0.3)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // MARK: - Window position persistence

    private var windowPositionKey: String? {
        guard let dir = appState.projectDirectory else { return nil }
        return "windowTopLeft:\(dir.appendingPathComponent("package.json").path)"
    }

    private func saveWindowPosition() {
        guard let key = windowPositionKey, let win = window else { return }
        // Persist the top-left corner so it stays put regardless of window height changes.
        let topLeft = CGPoint(x: win.frame.origin.x,
                              y: win.frame.origin.y + win.frame.height)
        UserDefaults.standard.set(["x": Double(topLeft.x), "y": Double(topLeft.y)], forKey: key)
    }

    private func restoreWindowPosition() {
        guard let key = windowPositionKey,
              let dict = UserDefaults.standard.dictionary(forKey: key),
              let x = dict["x"] as? Double,
              let y = dict["y"] as? Double,
              let win = window else { return }
        // Re-anchor from the saved top-left corner (origin is bottom-left on macOS).
        let origin = CGPoint(x: CGFloat(x), y: CGFloat(y) - win.frame.height)
        // Clamp to visible screen area.
        if let screen = win.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            let cx = min(max(origin.x, visible.minX), visible.maxX - win.frame.width)
            let cy = min(max(origin.y, visible.minY), visible.maxY - win.frame.height)
            win.setFrameOrigin(CGPoint(x: cx, y: cy))
        } else {
            win.setFrameOrigin(origin)
        }
    }

    // MARK: - Helpers

    private func setupMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(
            withTitle: "Quit npm remote control",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        NSApp.mainMenu = menu
    }

    private func sizeWindowToContent() {
        guard let win = window, let fh = fittingHeight else { return }
        let h = min(max(fh(), 80), 600)
        var f = win.frame
        f.origin.y += f.height - h // keep the top edge fixed
        f.size.height = h
        win.setFrame(f, display: true)
        win.invalidateShadow()
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) { saveWindowPosition() }
    func windowDidEndLiveResize(_ notification: Notification) { saveWindowPosition() }
}
