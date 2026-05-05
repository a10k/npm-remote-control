import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
            Divider()
            mainContent
            Divider()
            footer
        }
        .frame(width: 280)
        .glassEffect(in: .rect(cornerRadius: 12))
    }

    @ViewBuilder
    private var mainContent: some View {
        if let error = state.loadError {
            statusText("Invalid package.json\n\(error)")
        } else if let project = state.project {
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
        .frame(maxHeight: 520)
    }

    private func statusText(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(20)
            .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
                        as? String ?? "0.1"
        return Text("npm remote control · v\(version)")
            .font(.system(size: 10))
            .foregroundColor(.secondary)
            .opacity(0.5)
            .padding(.vertical, 7)
    }
}
