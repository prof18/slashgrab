import SlashgrabCore
import SwiftUI

struct MenuPopoverView: View {
    @ObservedObject var appState: AppState
    let buildInfo: AppBuildInfo
    let updater: UpdaterControlling
    let onAbout: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Picker("Copy As", selection: Binding(
                get: { appState.selectedFormat },
                set: { appState.setSelectedFormat($0) }
            )) {
                ForEach(PathFormat.allCases) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .pickerStyle(.menu)
            .focusable(false)

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

            historyMenu

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

                Button {
                    onAbout()
                } label: {
                    Label("About", systemImage: "info.circle")
                }

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

    private var historyMenu: some View {
        Menu {
            if appState.history.entries.isEmpty {
                Text("No copied paths yet")
            } else {
                Section("Copy again") {
                    ForEach(appState.history.entries, id: \.self) { output in
                        Button {
                            appState.copyAgain(output)
                        } label: {
                            Label(historyMenuTitle(for: output), systemImage: "doc.on.doc")
                        }
                        .help(output)
                    }
                }

                Divider()

                Button(role: .destructive) {
                    appState.clearHistory()
                } label: {
                    Label("Clear History", systemImage: "trash")
                }
            }
        } label: {
            HStack(spacing: 8) {
                Label("Recently grabbed", systemImage: "clock.arrow.circlepath")
                    .font(.custom("Avenir Next", size: 12).weight(.semibold))
                Spacer()
                Text(historyCountTitle)
                    .font(.custom("Avenir Next", size: 11).weight(.semibold))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 7))
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var historyCountTitle: String {
        let count = appState.history.entries.count
        return count == 1 ? "1 item" : "\(count) items"
    }

    private func historyMenuTitle(for output: String) -> String {
        let normalized = output
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.count > 30 else {
            return normalized
        }

        let head = normalized.prefix(13)
        let tail = normalized.suffix(14)
        return "\(head)...\(tail)"
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: AppIconProvider.image())
                .resizable()
                .interpolation(.high)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("Slashgrab")
                        .font(.custom("Avenir Next", size: 16).weight(.bold))

                    if buildInfo.isDevBuild {
                        Text("DEV")
                            .font(.custom("Avenir Next", size: 9).weight(.heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.orange, in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                Text(buildInfo.isDevBuild ? "Development build" : "Drop files. Grab paths.")
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
