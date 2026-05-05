import SwiftUI

struct ScriptRow: View {
    let script: Script
    @EnvironmentObject var state: AppState

    private var scriptState: ScriptState { state.states[script.id] ?? .idle }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(script.id)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer()
                stateIcon.frame(width: 20, height: 20)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { handleTap() }

            if state.expanded.contains(script.id) {
                TerminalPanel(scriptName: script.id)
            }
        }
    }

    private func handleTap() {
        switch scriptState {
        case .idle, .exited:
            state.run(script: script)
        case .running:
            // Toggle the terminal panel while the script is running.
            if state.expanded.contains(script.id) {
                state.expanded.remove(script.id)
            } else {
                state.expanded.insert(script.id)
            }
        }
    }

    @ViewBuilder
    private var stateIcon: some View {
        switch scriptState {
        case .idle:
            Image(systemName: "play.fill")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        case .running:
            ProgressView().scaleEffect(0.7)
        case .exited(let code, _):
            Image(systemName: code == 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 13))
                .foregroundColor(code == 0 ? .green : .red)
        }
    }
}
