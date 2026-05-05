import AppKit
import Combine
import SwiftUI

final class AppState: ObservableObject, @unchecked Sendable {
    @Published var project: PackageJSON?
    @Published var projectDirectory: URL?
    @Published var states: [String: ScriptState] = [:]
    @Published var expanded: Set<String> = []
    // Mutated in place; callers send objectWillChange manually.
    @Published var outputs: [String: OutputBuffer] = [:]

    let runner = ScriptRunner()

    // MARK: - Project loading

    func load() {
        guard let located = ProjectLocator.findPackageJSON() else {
            project = nil
            projectDirectory = nil
            return
        }
        projectDirectory = located.directory
        reload(from: located.file)
    }

    /// Re-read package.json and reset all script state.
    func reload() {
        guard let dir = projectDirectory else { load(); return }
        Task { await runner.terminateAll() }
        states = [:]
        outputs = [:]
        expanded = []
        reload(from: dir.appendingPathComponent("package.json"))
    }

    private func reload(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            project = try PackageJSON.parse(from: data)
        } catch {
            project = nil
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
        expanded.insert(name) // auto-open terminal panel

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
                            self.states[name] = .exited(code: code, at: Date())
                            if code == 0 {
                                // Auto-collapse the panel after a clean exit.
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    self.expanded.remove(name)
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
                        "Error: could not start npm — is it in your PATH?\n\(error.localizedDescription)\n"
                    )
                    self.objectWillChange.send()
                    self.states[name] = .exited(code: 1, at: Date())
                }
            }
        }
    }

    func stop(scriptNamed name: String) {
        Task { await runner.terminate(name) }
    }

    private func appendOutput(_ chunk: String, for name: String) {
        guard let buffer = outputs[name] else { return }
        // Normalise CR+LF and bare CR (progress bars) to LF before display.
        let normalized = chunk
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        objectWillChange.send()
        buffer.append(ANSI.strip(normalized))
    }
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: BorderlessWindow?
    let appState = AppState()
    private var cancellables = Set<AnyCancellable>()
    private var fittingHeight: (() -> CGFloat)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()
        appState.load()

        let win = BorderlessWindow()
        let visualEffect = makeVisualEffectView()

        let hv = NSHostingView(rootView: ContentView().environmentObject(appState))
        hv.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(hv)
        NSLayoutConstraint.activate([
            hv.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            hv.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            hv.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            hv.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
        ])
        win.contentView = visualEffect
        fittingHeight = { hv.fittingSize.height }
        window = win

        // Resize when scripts load/reload or terminal panels expand/collapse.
        for pub in [appState.$project.map { _ in () }.eraseToAnyPublisher(),
                    appState.$expanded.map { _ in () }.eraseToAnyPublisher()] {
            pub.receive(on: DispatchQueue.main)
               .sink { [weak self] in
                   DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                       self?.sizeWindowToContent()
                   }
               }
               .store(in: &cancellables)
        }

        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Kill all child processes before the app exits.
        Task { await appState.runner.terminateAll() }
        Thread.sleep(forTimeInterval: 0.3) // allow SIGTERM to propagate
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

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

    private func makeVisualEffectView() -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .sidebar
        v.blendingMode = .behindWindow
        v.state = .active
        v.wantsLayer = true
        v.layer?.cornerRadius = 12
        v.layer?.masksToBounds = true
        return v
    }

    private func sizeWindowToContent() {
        guard let win = window, let fh = fittingHeight else { return }
        let h = min(max(fh(), 80), 600)
        var f = win.frame
        f.origin.y += f.height - h
        f.size.height = h
        win.setFrame(f, display: true)
        win.invalidateShadow()
    }
}
