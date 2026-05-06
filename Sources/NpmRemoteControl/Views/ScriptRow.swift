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
