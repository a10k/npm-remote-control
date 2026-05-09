import SwiftUI

struct TerminalPanel: View {
    let scriptName: String
    @EnvironmentObject var state: AppState

    private var output: String { state.outputs[scriptName]?.text ?? "" }

    private var failCode: Int32? {
        guard case .exited(let code, _) = state.states[scriptName], code != 0 else { return nil }
        return code
    }

    var body: some View {
        VStack(spacing: 0) {
            scrollPane
            if let code = failCode { exitBadge(code) }
        }
    }

    private var scrollPane: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                Text(output.isEmpty ? " " : output)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(white: 0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .textSelection(.enabled)
                Color.clear.frame(height: 1).id("bottom")
            }
            .onChange(of: output.count) {
                proxy.scrollTo("bottom")
            }
        }
        .frame(height: 200)
        .background(Color(white: 0.1))
    }

    private func exitBadge(_ code: Int32) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "xmark.circle.fill")
            Text("exited with code \(code)")
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(.red)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(white: 0.1))
    }
}
