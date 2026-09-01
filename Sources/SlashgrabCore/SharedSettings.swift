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
