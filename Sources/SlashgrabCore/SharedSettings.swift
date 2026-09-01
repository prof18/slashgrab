import Foundation

public enum SharedSettings {
    public static let appGroupIdentifierInfoKey = "SlashgrabAppGroupIdentifier"

    public static func makeStore(bundle: Bundle = .main) -> AppSettingsStore? {
        makeStore(appGroupIdentifier: appGroupIdentifier(in: bundle))
    }

    public static func makeStore(appGroupIdentifier: String?) -> AppSettingsStore? {
        makeDefaults(appGroupIdentifier: appGroupIdentifier)
            .map(AppSettingsStore.init(defaults:))
    }

    public static func makePathFormatReader(bundle: Bundle = .main) -> SharedPathFormatReader? {
        makePathFormatReader(appGroupIdentifier: appGroupIdentifier(in: bundle))
    }

    public static func makePathFormatReader(appGroupIdentifier: String?) -> SharedPathFormatReader? {
        makeDefaults(appGroupIdentifier: appGroupIdentifier)
            .map(SharedPathFormatReader.init(defaults:))
    }

    public static func makeFinderExtensionVersionStore(bundle: Bundle = .main) -> SharedFinderExtensionVersionStore? {
        makeFinderExtensionVersionStore(appGroupIdentifier: appGroupIdentifier(in: bundle))
    }

    public static func makeFinderExtensionVersionStore(
        appGroupIdentifier: String?
    ) -> SharedFinderExtensionVersionStore? {
        makeDefaults(appGroupIdentifier: appGroupIdentifier)
            .map(SharedFinderExtensionVersionStore.init(defaults:))
    }

    public static func finderExtensionVersion(bundle: Bundle = .main) -> String? {
        guard let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              let buildNumber = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String else {
            return nil
        }

        return "\(shortVersion) (\(buildNumber))"
    }

    private static func appGroupIdentifier(in bundle: Bundle) -> String? {
        bundle.object(forInfoDictionaryKey: appGroupIdentifierInfoKey) as? String
    }

    private static func makeDefaults(appGroupIdentifier: String?) -> UserDefaults? {
        guard let appGroupIdentifier,
              !appGroupIdentifier.isEmpty,
              !appGroupIdentifier.contains("$(") else {
            return nil
        }

        return UserDefaults(suiteName: appGroupIdentifier)
    }
}

public final class SharedFinderExtensionVersionStore: @unchecked Sendable {
    private static let activeVersionKey = "activeFinderExtensionVersion"

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func activate(version: String) {
        defaults.set(version, forKey: Self.activeVersionKey)
    }

    public func isActive(version: String) -> Bool {
        guard let activeVersion = defaults.string(forKey: Self.activeVersionKey) else {
            return true
        }

        return activeVersion == version
    }
}

public final class SharedPathFormatReader: NSObject, @unchecked Sendable {
    private let defaults: UserDefaults
    private let lock = NSLock()
    private var cachedFormat = PathFormat.shellEscaped

    init(defaults: UserDefaults) {
        self.defaults = defaults
        super.init()
        defaults.addObserver(
            self,
            forKeyPath: AppSettingsStore.selectedFormatKey,
            options: [.initial, .new],
            context: nil
        )
    }

    deinit {
        defaults.removeObserver(self, forKeyPath: AppSettingsStore.selectedFormatKey)
    }

    public var selectedFormat: PathFormat {
        lock.lock()
        defer { lock.unlock() }
        return cachedFormat
    }

    public override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard keyPath == AppSettingsStore.selectedFormatKey else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }

        let rawValue = change?[.newKey] as? String
        let format = rawValue.flatMap(PathFormat.init(rawValue:)) ?? .shellEscaped

        lock.lock()
        cachedFormat = format
        lock.unlock()
    }
}
