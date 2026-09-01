import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState.production()
    let updater = SparkleUpdater()

    private var statusItemController: StatusItemController?
    private let finderExtensionUpdateController = FinderExtensionUpdateController.production()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        finderExtensionUpdateController.refreshRunningHostsIfNeeded()

        let controller = StatusItemController(appState: appState)
        controller.install()

        statusItemController = controller
    }
}
