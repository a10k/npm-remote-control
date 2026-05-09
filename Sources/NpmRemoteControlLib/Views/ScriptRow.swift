import AppKit
import SwiftUI

struct ScriptRow: View {
    let script: Script
    @EnvironmentObject var state: AppState

    private var scriptState: ScriptState { state.states[script.id] ?? .idle }
    private var isExpanded: Bool { state.expanded.contains(script.id) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if case .running = scriptState {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.15), value: isExpanded)
                        .frame(width: 12)
                }
                Text(script.id)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                trailingIcon
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onHover { hovering in hovering ? NSCursor.pointingHand.push() : NSCursor.pop() }
            .onTapGesture { handleTap() }
            .contextMenu { contextMenuItems }

            if isExpanded {
                TerminalPanel(scriptName: script.id)
                    .padding(.horizontal, 12)
            }
        }
    }

    private func handleTap() {
        switch scriptState {
        case .idle, .exited:
            state.run(script: script)
        case .running:
            state.expanded.formSymmetricDifference([script.id])
        }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        switch scriptState {
        case .running:
            Button(role: .destructive) { state.stop(scriptNamed: script.id) } label: {
                Label("Kill", systemImage: "stop.fill")
            }
        case .exited:
            Button { state.reset(scriptNamed: script.id) } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
        case .idle:
            EmptyView()
        }
    }

    @ViewBuilder
    private var trailingIcon: some View {
        switch scriptState {
        case .idle:
            Image(systemName: "play.fill")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
        case .running:
            Button { state.stop(scriptNamed: script.id) } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("Kill")
        case .exited(let code, _):
            Image(systemName: code == 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(code == 0 ? Color.green : Color.red)
                .frame(width: 20, height: 20)
        }
    }
}

#Preview("Idle") {
    let state = AppState()
    state.project = PackageJSON(name: "my-app", scripts: [
        Script(id: "dev", command: "vite"),
        Script(id: "build", command: "tsc && vite build"),
        Script(id: "lint", command: "eslint ."),
        Script(id: "test", command: "vitest run"),
    ])
    return VStack(spacing: 0) {
        ForEach(state.project!.scripts) { script in
            ScriptRow(script: script)
            Divider().padding(.leading, 12)
        }
    }
    .frame(width: 280)
    .environmentObject(state)
}

#Preview("Running – Long Output") {
    let state = AppState()
    state.project = PackageJSON(name: "my-app", scripts: [
        Script(id: "dev", command: "vite"),
        Script(id: "build", command: "tsc && vite build"),
        Script(id: "lint", command: "eslint ."),
        Script(id: "test", command: "vitest run"),
    ])
    state.states["dev"] = .running(pid: 1234, startedAt: Date())
    state.expanded.insert("dev")

    let mockOutput = OutputBuffer()
    let lines = (1...80).map { i -> String in
        switch i % 5 {
        case 0: return "[\(String(format: "%02d:%02d:%02d", i / 60, i % 60, 0))] hmr update /src/components/App.tsx"
        case 1: return "  VITE v5.2.0  ready in 342 ms"
        case 2: return "  ➜  Local:   http://localhost:5173/"
        case 3: return "  ➜  Network: http://192.168.1.42:5173/"
        default: return "  page reload  src/main.tsx"
        }
    }
    mockOutput.append(lines.joined(separator: "\n"))
    state.outputs["dev"] = mockOutput

    return ScrollView(.vertical, showsIndicators: false) {
        LazyVStack(spacing: 0) {
            ForEach(state.project!.scripts) { script in
                ScriptRow(script: script)
                Divider().padding(.leading, 12)
            }
        }
    }
    .frame(width: 280, height: 200)
    .clipped()
    .environmentObject(state)
}

#Preview("your-npm-project") {
    let state = AppState()
    state.project = PackageJSON(name: "your-npm-project", scripts: [
        Script(id: "dev", command: "vite"),
        Script(id: "build", command: "tsc && vite build"),
        Script(id: "lint", command: "eslint ."),
        Script(id: "test", command: "vitest run"),
    ])
    state.states["dev"] = .running(pid: 1234, startedAt: Date())
    state.expanded.insert("dev")

    let mockOutput = OutputBuffer()
    mockOutput.append("  VITE v5.2.0  ready in 132 ms")
    state.outputs["dev"] = mockOutput

    return VStack(spacing: 0) {
        ForEach(state.project!.scripts) { script in
            ScriptRow(script: script)
            if script.id != "test" { Divider().padding(.leading, 12) }
        }
    }
    .frame(width: 260)
    .environmentObject(state)
}

#Preview("Exited") {
    let state = AppState()
    state.project = PackageJSON(name: "my-app", scripts: [
        Script(id: "build", command: "tsc && vite build"),
        Script(id: "test", command: "vitest run"),
        Script(id: "lint", command: "eslint ."),
    ])
    state.states["build"] = .exited(code: 0, at: Date())
    state.states["test"] = .exited(code: 1, at: Date())
    return VStack(spacing: 0) {
        ForEach(state.project!.scripts) { script in
            ScriptRow(script: script)
            Divider().padding(.leading, 12)
        }
    }
    .frame(width: 280)
    .environmentObject(state)
}
