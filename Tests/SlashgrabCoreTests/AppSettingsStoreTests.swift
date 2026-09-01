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

    @Test("Shared settings reject missing and unresolved app group identifiers")
    func invalidSharedSettingsIdentifiers() {
        #expect(SharedSettings.makeStore(appGroupIdentifier: nil) == nil)
        #expect(SharedSettings.makeStore(appGroupIdentifier: "") == nil)
        #expect(SharedSettings.makeStore(appGroupIdentifier: "$(APP_GROUP_ID)") == nil)
        #expect(SharedSettings.makePathFormatReader(appGroupIdentifier: nil) == nil)
        #expect(SharedSettings.makePathFormatReader(appGroupIdentifier: "") == nil)
        #expect(SharedSettings.makePathFormatReader(appGroupIdentifier: "$(APP_GROUP_ID)") == nil)
    }

    @Test("Shared path format reader observes changes after initialization")
    func sharedPathFormatReaderObservesChanges() {
        let defaults = makeDefaults()
        let reader = SharedPathFormatReader(defaults: defaults)

        #expect(reader.selectedFormat == .shellEscaped)

        defaults.set(PathFormat.fileURL.rawValue, forKey: AppSettingsStore.selectedFormatKey)

        #expect(reader.selectedFormat == .fileURL)
    }

    @Test("Shared path format reader falls back after an invalid update")
    func sharedPathFormatReaderFallsBackAfterInvalidUpdate() {
        let defaults = makeDefaults()
        defaults.set(PathFormat.doubleQuoted.rawValue, forKey: AppSettingsStore.selectedFormatKey)
        let reader = SharedPathFormatReader(defaults: defaults)

        #expect(reader.selectedFormat == .doubleQuoted)

        defaults.set("invalid-format", forKey: AppSettingsStore.selectedFormatKey)

        #expect(reader.selectedFormat == .shellEscaped)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "com.prof18.slashgrab.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
