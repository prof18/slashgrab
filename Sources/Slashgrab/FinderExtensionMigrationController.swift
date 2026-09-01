import AppKit
import FinderSync

@MainActor
struct FinderExtensionMigrationController {
    private static let migrationCompletedKey = "finderExtensionVersionGateMigrationCompleted"

    private let defaults: UserDefaults
    private let isExtensionEnabled: () -> Bool
    private let relaunchFinder: () -> Bool

    init(
        defaults: UserDefaults,
        isExtensionEnabled: @escaping () -> Bool,
        relaunchFinder: @escaping () -> Bool
    ) {
        self.defaults = defaults
        self.isExtensionEnabled = isExtensionEnabled
        self.relaunchFinder = relaunchFinder
    }

    static func production(bundle: Bundle = .main) -> FinderExtensionMigrationController {
        let appBundleIdentifier = bundle.bundleIdentifier ?? "com.prof18.slashgrab.dev"
        let defaults = UserDefaults(suiteName: appBundleIdentifier) ?? .standard

        return FinderExtensionMigrationController(
            defaults: defaults,
            isExtensionEnabled: { FIFinderSyncController.isExtensionEnabled },
            relaunchFinder: {
                NSRunningApplication
                    .runningApplications(withBundleIdentifier: "com.apple.finder")
                    .map { $0.forceTerminate() }
                    .contains(true)
            }
        )
    }

    func migrateIfNeeded() {
        guard !defaults.bool(forKey: Self.migrationCompletedKey) else {
            return
        }

        guard isExtensionEnabled() else {
            defaults.set(true, forKey: Self.migrationCompletedKey)
            return
        }

        if relaunchFinder() {
            defaults.set(true, forKey: Self.migrationCompletedKey)
        }
    }
}
