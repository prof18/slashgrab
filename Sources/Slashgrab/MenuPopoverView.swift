import SlashgrabCore
import SwiftUI

struct MenuPopoverView: View {
    @ObservedObject var appState: AppState
    let updater: UpdaterControlling
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Picker("Format", selection: Binding(
                get: { appState.selectedFormat },
                set: { appState.setSelectedFormat($0) }
            )) {
                ForEach(PathFormat.allCases) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .pickerStyle(.menu)

            DropZoneView(
                onDrop: { appState.handleDroppedURLs($0) },
                onRejectedDrop: { appState.handleDroppedURLs([]) }
            )
            .frame(height: 58)

            if let output = appState.lastCopiedOutput {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Last copied")
                        .font(.custom("Avenir Next", size: 11).weight(.semibold))
                        .foregroundStyle(.secondary)
                    RecentPathRow(output: output) {
                        appState.copyAgain(output)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Recent")
                        .font(.custom("Avenir Next", size: 12).weight(.semibold))
                    Spacer()
                    Button {
                        appState.clearHistory()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .disabled(appState.history.entries.isEmpty)
                }

                if appState.history.entries.isEmpty {
                    Text("No copied paths yet")
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 18)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(appState.history.entries, id: \.self) { output in
                                RecentPathRow(output: output) {
                                    appState.copyAgain(output)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 170)
                }
            }

            Divider()

            Toggle("Launch at login", isOn: Binding(
                get: { appState.launchAtLoginEnabled },
                set: { appState.setLaunchAtLoginEnabled($0) }
            ))

            HStack {
                Button {
                    updater.checkForUpdates()
                } label: {
                    Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(!updater.canCheckForUpdates)

                Spacer()

                Button(role: .destructive) {
                    onQuit()
                } label: {
                    Label("Quit", systemImage: "power")
                }
            }
        }
        .padding(16)
        .frame(width: 360)
        .font(.custom("Avenir Next", size: 13))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("/")
                .font(.system(size: 24, weight: .black, design: .monospaced))
                .frame(width: 32, height: 32)
                .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 1) {
                Text("Slashgrab")
                    .font(.custom("Avenir Next", size: 16).weight(.bold))
                Text("Drop files. Grab paths.")
                    .font(.custom("Avenir Next", size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let feedback = appState.feedback {
                Label(feedback.message, systemImage: feedback.kind == .success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .font(.custom("Avenir Next", size: 11).weight(.semibold))
                    .foregroundStyle(feedback.kind == .success ? .green : .red)
                    .lineLimit(1)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.snappy(duration: 0.18), value: appState.feedback)
    }
}
