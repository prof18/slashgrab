import AppKit
import SwiftUI

struct SettingsView<Updater: UpdaterControlling>: View {
    @ObservedObject var appState: AppState
    let buildInfo: AppBuildInfo
    @ObservedObject var updater: Updater

    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            AboutView(
                buildInfo: buildInfo,
                canCheckForUpdates: updater.canCheckForUpdates,
                onCheckForUpdates: updater.checkForUpdates
            )
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
        .frame(minWidth: 520, idealWidth: 520, minHeight: 340, idealHeight: 340)
        .font(.custom("Avenir Next", size: 13, relativeTo: .body))
        .onAppear {
            appState.refreshLaunchAtLoginStatus()
            appState.refreshFinderExtensionStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            appState.refreshLaunchAtLoginStatus()
            appState.refreshFinderExtensionStatus()
        }
    }

    private var generalSettings: some View {
        Form {
            Section("Startup") {
                Toggle("Launch Slashgrab at login", isOn: Binding(
                    get: { appState.launchAtLoginEnabled },
                    set: { appState.setLaunchAtLoginEnabled($0) }
                ))

                Text("Keeps Slashgrab ready in the menu bar after you sign in.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Finder") {
                LabeledContent("Copy Path extension") {
                    Label(
                        appState.finderExtensionEnabled ? "Enabled" : "Not enabled",
                        systemImage: appState.finderExtensionEnabled ? "checkmark.circle.fill" : "circle.dashed"
                    )
                    .foregroundStyle(appState.finderExtensionEnabled ? .green : .secondary)
                }

                Button("Open Finder Extension Settings…") {
                    appState.showFinderExtensionSettings()
                }

                Text("Enable the extension to add Copy Path to Finder’s right-click menu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 8)
    }
}
