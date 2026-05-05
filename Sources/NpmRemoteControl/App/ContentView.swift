import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
            Divider()
            mainContent
        }
        .frame(width: 280)
    }

    @ViewBuilder
    private var mainContent: some View {
        if let project = state.project {
            if project.scripts.isEmpty {
                statusText("No scripts defined in package.json.")
            } else {
                scriptList(project.scripts)
            }
        } else {
            statusText("No package.json found.\nDrop this app into an npm project folder.")
        }
    }

    private func scriptList(_ scripts: [Script]) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(scripts.enumerated()), id: \.element.id) { i, script in
                    if i > 0 { Divider().padding(.leading, 12) }
                    ScriptRow(script: script)
                }
            }
        }
        .frame(maxHeight: 556)
    }

    private func statusText(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(20)
            .frame(maxWidth: .infinity)
    }
}
