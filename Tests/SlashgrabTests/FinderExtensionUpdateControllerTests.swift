import Foundation
import Testing
@testable import Slashgrab

@Suite("Finder extension update controller")
@MainActor
struct FinderExtensionUpdateControllerTests {
    @Test("Running extension hosts are refreshed once for a new app version")
    func refreshesOnceForNewVersion() {
        let defaults = makeDefaults()
        var terminationCount = 0
        let controller = FinderExtensionUpdateController(
            defaults: defaults,
            appVersion: "0.0.3 (3)",
            terminateRunningExtensionHosts: { terminationCount += 1 }
        )

        controller.refreshRunningHostsIfNeeded()
        controller.refreshRunningHostsIfNeeded()

        #expect(terminationCount == 1)
    }

    @Test("Running extension hosts are refreshed again after an app update")
    func refreshesAgainAfterUpdate() {
        let defaults = makeDefaults()
        var terminationCount = 0
        let oldController = FinderExtensionUpdateController(
            defaults: defaults,
            appVersion: "0.0.2 (2)",
            terminateRunningExtensionHosts: { terminationCount += 1 }
        )
        let updatedController = FinderExtensionUpdateController(
            defaults: defaults,
            appVersion: "0.0.3 (3)",
            terminateRunningExtensionHosts: { terminationCount += 1 }
        )

        oldController.refreshRunningHostsIfNeeded()
        updatedController.refreshRunningHostsIfNeeded()

        #expect(terminationCount == 2)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "com.prof18.slashgrab.finder-update-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
