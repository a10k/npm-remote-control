import AppKit
import Combine
import SwiftUI

final class AppState: ObservableObject {
    @Published var project: PackageJSON?
    @Published var projectDirectory: URL?
    @Published var states: [String: ScriptState] = [:]
    @Published var expanded: Set<String> = []

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
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: BorderlessWindow?
    let appState = AppState()
    private var cancellables = Set<AnyCancellable>()
    // Captures the hosting view without naming its opaque generic parameter.
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

        // Resize whenever scripts load or change (e.g., refresh).
        appState.$project
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Defer one run loop so SwiftUI finishes its layout pass first.
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
