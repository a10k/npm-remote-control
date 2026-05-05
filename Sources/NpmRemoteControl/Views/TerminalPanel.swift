import SwiftUI

struct TerminalPanel: View {
    let scriptName: String
    @EnvironmentObject var state: AppState

    private var output: String { state.outputs[scriptName]?.text ?? "" }

    private var scriptState: ScriptState { state.states[scriptName] ?? .idle }

    private var isRunning: Bool {
        if case .running = scriptState { return true }
        return false
    }

    private var failCode: Int32? {
        if case .exited(let code, _) = scriptState, code != 0 { return code }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                scrollPane
                if isRunning { killButton }
            }
            if let code = failCode { exitBadge(code) }
        }
    }

    private var scrollPane: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                Text(output.isEmpty ? " " : output)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(white: 0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .textSelection(.enabled)
                Color.clear.frame(height: 1).id("bottom")
            }
            .onChange(of: output.count) { _ in
                proxy.scrollTo("bottom")
            }
        }
        .frame(height: 200)
        .background(Color(white: 0.1))
    }

    private var killButton: some View {
        Button { state.stop(scriptNamed: scriptName) } label: {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.75))
                .frame(width: 18, height: 18)
                .background(Color.white.opacity(0.18))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(6)
    }

    private func exitBadge(_ code: Int32) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "xmark.circle.fill")
            Text("exited with code \(code)")
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundColor(.red)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(white: 0.1))
    }
}
