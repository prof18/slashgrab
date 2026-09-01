import AppKit

@MainActor
struct FinderExtensionUpdateController {
    private static let refreshedVersionKey = "finderExtensionLastRefreshedVersion"

    private let defaults: UserDefaults
    private let appVersion: String
    private let terminateRunningExtensionHosts: () -> Void

    init(
        defaults: UserDefaults,
        appVersion: String,
        terminateRunningExtensionHosts: @escaping () -> Void
    ) {
        self.defaults = defaults
        self.appVersion = appVersion
        self.terminateRunningExtensionHosts = terminateRunningExtensionHosts
    }

    static func production(bundle: Bundle = .main) -> FinderExtensionUpdateController {
        let appBundleIdentifier = bundle.bundleIdentifier ?? "com.prof18.slashgrab.dev"
        let extensionBundleIdentifier = "\(appBundleIdentifier).findersync"
        let defaults = UserDefaults(suiteName: appBundleIdentifier) ?? .standard
        let marketingVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let buildNumber = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"

        return FinderExtensionUpdateController(
            defaults: defaults,
            appVersion: "\(marketingVersion) (\(buildNumber))",
            terminateRunningExtensionHosts: {
                NSRunningApplication
                    .runningApplications(withBundleIdentifier: extensionBundleIdentifier)
                    .forEach { $0.terminate() }
            }
        )
    }

    func refreshRunningHostsIfNeeded() {
        guard defaults.string(forKey: Self.refreshedVersionKey) != appVersion else {
            return
        }

        terminateRunningExtensionHosts()
        defaults.set(appVersion, forKey: Self.refreshedVersionKey)
    }
}
