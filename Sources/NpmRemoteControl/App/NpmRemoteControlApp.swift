import AppKit
import Combine
import SwiftUI

final class AppState: ObservableObject, @unchecked Sendable {
    @Published var project: PackageJSON?
    @Published var projectDirectory: URL?
    @Published var states: [String: ScriptState] = [:]
    // outputs values are mutated in place; callers must trigger objectWillChange manually.
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

    func reload() {
        guard let dir = projectDirectory else { load(); return }
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

        // Ignore taps on already-running scripts.
        if case .running = states[name] { return }

        let startTime = Date()
        outputs[name] = OutputBuffer()
        states[name] = .running(pid: -1, startedAt: startTime)

        Task { [weak self] in
            guard let self else { return }
            do {
                let pid = try await self.runner.run(
                    name, in: dir,
                    onOutput: { [weak self] chunk in
                        DispatchQueue.main.async { self?.appendOutput(chunk, for: name) }
                    },
                    onExit: { [weak self] code in
                        DispatchQueue.main.async {
                            self?.states[name] = .exited(code: code, at: Date())
                        }
                    }
                )
                DispatchQueue.main.async { [weak self] in
                    // Update with real PID now that the process is confirmed launched.
                    self?.states[name] = .running(pid: pid, startedAt: startTime)
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.states[name] = .exited(code: 1, at: Date())
                }
            }
        }
    }

    func stop(script: Script) {
        Task { await runner.terminate(script.id) }
    }

    private func appendOutput(_ chunk: String, for name: String) {
        guard let buffer = outputs[name] else { return }
        objectWillChange.send()
        buffer.append(ANSI.strip(chunk))
    }
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: BorderlessWindow?
    let appState = AppState()
    private var cancellables = Set<AnyCancellable>()
    private var fittingHeight: (() -> CGFloat)?

    func applicationDidFinishLaunching(_ notification: Notification) {
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

        appState.$project
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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

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
