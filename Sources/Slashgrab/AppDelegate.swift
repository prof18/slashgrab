import AppKit
import SlashgrabCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState.production()
    let updater = SparkleUpdater()

    private var statusItemController: StatusItemController?
    private let finderExtensionMigrationController = FinderExtensionMigrationController.production()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if let version = SharedSettings.finderExtensionVersion() {
            SharedSettings.makeFinderExtensionVersionStore()?.activate(version: version)
        }
        finderExtensionMigrationController.migrateIfNeeded()

        let controller = StatusItemController(appState: appState)
        controller.install()

        statusItemController = controller
    }
}
