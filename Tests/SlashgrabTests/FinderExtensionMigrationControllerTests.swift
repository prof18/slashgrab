import Foundation
import Testing
@testable import Slashgrab

@Suite("Finder extension migration controller")
@MainActor
struct FinderExtensionMigrationControllerTests {
    @Test("Finder is relaunched once when the extension is enabled")
    func relaunchesFinderOnce() {
        let defaults = makeDefaults()
        var relaunchCount = 0
        let controller = FinderExtensionMigrationController(
            defaults: defaults,
            isExtensionEnabled: { true },
            relaunchFinder: {
                relaunchCount += 1
                return true
            }
        )

        controller.migrateIfNeeded()
        controller.migrateIfNeeded()

        #expect(relaunchCount == 1)
    }

    @Test("Finder is not relaunched when the extension is disabled")
    func skipsRelaunchWhenDisabled() {
        let defaults = makeDefaults()
        var relaunchCount = 0
        let controller = FinderExtensionMigrationController(
            defaults: defaults,
            isExtensionEnabled: { false },
            relaunchFinder: {
                relaunchCount += 1
                return true
            }
        )

        controller.migrateIfNeeded()
        controller.migrateIfNeeded()

        #expect(relaunchCount == 0)
    }

    @Test("A failed Finder relaunch is retried")
    func retriesFailedRelaunch() {
        let defaults = makeDefaults()
        var relaunchCount = 0
        let controller = FinderExtensionMigrationController(
            defaults: defaults,
            isExtensionEnabled: { true },
            relaunchFinder: {
                relaunchCount += 1
                return relaunchCount == 2
            }
        )

        controller.migrateIfNeeded()
        controller.migrateIfNeeded()
        controller.migrateIfNeeded()

        #expect(relaunchCount == 2)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "com.prof18.slashgrab.finder-migration-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
