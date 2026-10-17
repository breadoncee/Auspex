import SwiftUI

struct UpdateSettingsView: View {
    @State private var checker = UpdateChecker()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("Check for Updates") { Task { await checker.check() } }
                    .disabled(checker.state == .checking)
                if checker.state == .checking {
                    ProgressView().controlSize(.small).accessibilityLabel("Checking for updates")
                }
            }
            switch checker.state {
            case .idle:
                Text("Checks GitHub only when you ask. Updates open in your browser.")
                    .font(.caption).foregroundStyle(.secondary)
            case .checking:
                Text("Checking GitHub…").font(.caption).foregroundStyle(.secondary)
            case .current:
                Label("You’re up to date.", systemImage: "checkmark.circle")
                    .font(.caption)
            case let .available(version, url):
                Link("Auspex \(version) is available — view release", destination: url)
                    .font(.subheadline)
            case let .failed(message):
                Label(message, systemImage: "exclamationmark.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
