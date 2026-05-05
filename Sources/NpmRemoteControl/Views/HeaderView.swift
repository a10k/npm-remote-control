import SwiftUI

struct HeaderView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack {
            Text(state.project?.name ?? "npm remote control")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button { state.reload() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Reload package.json")
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
    }
}
