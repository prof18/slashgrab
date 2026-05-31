import Foundation
import Testing
@testable import SlashgrabCore

@Suite("App settings store")
struct AppSettingsStoreTests {
    @Test("Defaults use shell escaped format and ten history items")
    func defaults() {
        let defaults = makeDefaults()
        let store = AppSettingsStore(defaults: defaults)
        #expect(store.selectedFormat == .shellEscaped)
        #expect(store.historyLimit == 10)
        #expect(store.loadHistory().entries.isEmpty)
    }

    @Test("Settings and history persist through user defaults")
    func persistence() {
        let defaults = makeDefaults()
        let store = AppSettingsStore(defaults: defaults)
        store.selectedFormat = .doubleQuoted
        store.historyLimit = 2
        store.launchAtLoginEnabled = true

        var history = PathHistory(limit: store.historyLimit)
        history.add("one")
        history.add("two")
        store.saveHistory(history)

        let reloaded = AppSettingsStore(defaults: defaults)
        #expect(reloaded.selectedFormat == .doubleQuoted)
        #expect(reloaded.historyLimit == 2)
        #expect(reloaded.launchAtLoginEnabled)
        #expect(reloaded.loadHistory().entries == ["two", "one"])
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "com.prof18.slashgrab.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
