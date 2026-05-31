import Foundation

public final class AppSettingsStore: @unchecked Sendable {
    private enum Key {
        static let selectedFormat = "selectedPathFormat"
        static let historyEntries = "historyEntries"
        static let historyLimit = "historyLimit"
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public var selectedFormat: PathFormat {
        get {
            guard let rawValue = defaults.string(forKey: Key.selectedFormat),
                  let format = PathFormat(rawValue: rawValue) else {
                return .shellEscaped
            }
            return format
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.selectedFormat)
        }
    }

    public var historyLimit: Int {
        get {
            let value = defaults.integer(forKey: Key.historyLimit)
            return value > 0 ? value : 10
        }
        set {
            defaults.set(max(1, newValue), forKey: Key.historyLimit)
        }
    }

    public var launchAtLoginEnabled: Bool {
        get {
            defaults.bool(forKey: Key.launchAtLoginEnabled)
        }
        set {
            defaults.set(newValue, forKey: Key.launchAtLoginEnabled)
        }
    }

    public func loadHistory() -> PathHistory {
        PathHistory(entries: defaults.stringArray(forKey: Key.historyEntries) ?? [], limit: historyLimit)
    }

    public func saveHistory(_ history: PathHistory) {
        defaults.set(history.limit, forKey: Key.historyLimit)
        defaults.set(history.entries, forKey: Key.historyEntries)
    }
}
