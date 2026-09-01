import Foundation
import Testing
@testable import Slashgrab
@testable import SlashgrabCore

@Suite("App state")
@MainActor
struct AppStateTests {
    @Test("Dropped URLs are formatted, copied, and persisted")
    func droppedURLsAreCopiedAndPersisted() {
        let defaults = makeDefaults()
        let sharedDefaults = makeDefaults()
        let settings = AppSettingsStore(defaults: defaults)
        let sharedSettings = AppSettingsStore(defaults: sharedDefaults)
        let clipboard = SpyClipboardWriter()
        let appState = AppState(
            settings: settings,
            sharedSettings: sharedSettings,
            formatter: PathFormatter(homeDirectory: URL(fileURLWithPath: "/Users/mg")),
            clipboardWriter: clipboard,
            launchAtLoginController: FakeLaunchAtLoginController(),
            finderExtensionController: FakeFinderExtensionController()
        )

        appState.setSelectedFormat(.doubleQuoted)
        let copied = appState.handleDroppedURLs([
            URL(fileURLWithPath: "/Users/mg/Desktop/Test File.txt"),
        ])

        #expect(copied)
        #expect(clipboard.writtenStrings == ["\"/Users/mg/Desktop/Test File.txt\""])
        #expect(appState.history.entries == ["\"/Users/mg/Desktop/Test File.txt\""])
        #expect(settings.loadHistory().entries == ["\"/Users/mg/Desktop/Test File.txt\""])
        #expect(sharedSettings.selectedFormat == .doubleQuoted)
    }

    @Test("The current format is migrated to shared Finder settings")
    func selectedFormatIsMigratedToSharedSettings() {
        let settings = AppSettingsStore(defaults: makeDefaults())
        settings.selectedFormat = .fileURL
        let sharedSettings = AppSettingsStore(defaults: makeDefaults())

        _ = AppState(
            settings: settings,
            sharedSettings: sharedSettings,
            clipboardWriter: SpyClipboardWriter(),
            launchAtLoginController: FakeLaunchAtLoginController(),
            finderExtensionController: FakeFinderExtensionController()
        )

        #expect(sharedSettings.selectedFormat == .fileURL)
    }

    @Test("Empty drops fail without writing clipboard or history")
    func emptyDropFailsWithoutSideEffects() {
        let settings = AppSettingsStore(defaults: makeDefaults())
        let clipboard = SpyClipboardWriter()
        let appState = AppState(
            settings: settings,
            clipboardWriter: clipboard,
            launchAtLoginController: FakeLaunchAtLoginController(),
            finderExtensionController: FakeFinderExtensionController()
        )

        let copied = appState.handleDroppedURLs([])

        #expect(!copied)
        #expect(clipboard.writtenStrings.isEmpty)
        #expect(appState.history.entries.isEmpty)
        #expect(appState.feedback?.kind == .failure)
        #expect(appState.feedback?.message == "Unsupported drop")
    }

    @Test("Clipboard failures do not persist history")
    func clipboardFailureDoesNotPersistHistory() {
        let settings = AppSettingsStore(defaults: makeDefaults())
        let clipboard = FailingClipboardWriter()
        let appState = AppState(
            settings: settings,
            clipboardWriter: clipboard,
            launchAtLoginController: FakeLaunchAtLoginController(),
            finderExtensionController: FakeFinderExtensionController()
        )

        let copied = appState.handleDroppedURLs([
            URL(fileURLWithPath: "/Users/mg/Desktop/Test File.txt"),
        ])

        #expect(!copied)
        #expect(appState.history.entries.isEmpty)
        #expect(settings.loadHistory().entries.isEmpty)
        #expect(appState.feedback?.kind == .failure)
        #expect(appState.feedback?.message == "Clipboard write failed")
    }

    @Test("Launch at login writes actual controller state")
    func launchAtLoginWritesActualControllerState() {
        let settings = AppSettingsStore(defaults: makeDefaults())
        let controller = FakeLaunchAtLoginController()
        let appState = AppState(
            settings: settings,
            clipboardWriter: SpyClipboardWriter(),
            launchAtLoginController: controller,
            finderExtensionController: FakeFinderExtensionController()
        )

        appState.setLaunchAtLoginEnabled(true)

        #expect(appState.launchAtLoginEnabled)
        #expect(settings.launchAtLoginEnabled)
        #expect(appState.feedback?.kind == .success)
        #expect(appState.feedback?.message == "Launch at login on")

        controller.errorToThrow = TestError.expected
        controller.isEnabled = false
        appState.setLaunchAtLoginEnabled(true)

        #expect(!appState.launchAtLoginEnabled)
        #expect(!settings.launchAtLoginEnabled)
        #expect(appState.feedback?.kind == .failure)
        #expect(appState.feedback?.message == "Launch at login failed")
    }

    @Test("Launch at login refresh uses the live service state")
    func launchAtLoginRefreshUsesLiveServiceState() {
        let settings = AppSettingsStore(defaults: makeDefaults())
        settings.launchAtLoginEnabled = true
        let controller = FakeLaunchAtLoginController()
        let appState = AppState(
            settings: settings,
            clipboardWriter: SpyClipboardWriter(),
            launchAtLoginController: controller,
            finderExtensionController: FakeFinderExtensionController()
        )

        #expect(!appState.launchAtLoginEnabled)
        #expect(!settings.launchAtLoginEnabled)

        controller.isEnabled = true
        appState.refreshLaunchAtLoginStatus()

        #expect(appState.launchAtLoginEnabled)
        #expect(settings.launchAtLoginEnabled)
    }

    @Test("Finder extension status refreshes and settings can be opened")
    func finderExtensionManagement() {
        let finderController = FakeFinderExtensionController()
        let appState = AppState(
            settings: AppSettingsStore(defaults: makeDefaults()),
            clipboardWriter: SpyClipboardWriter(),
            launchAtLoginController: FakeLaunchAtLoginController(),
            finderExtensionController: finderController
        )

        #expect(!appState.finderExtensionEnabled)

        finderController.isEnabled = true
        appState.refreshFinderExtensionStatus()
        appState.showFinderExtensionSettings()

        #expect(appState.finderExtensionEnabled)
        #expect(finderController.showManagementInterfaceCallCount == 1)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "com.prof18.slashgrab.app-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private final class SpyClipboardWriter: ClipboardWriting, @unchecked Sendable {
    private(set) var writtenStrings: [String] = []

    func writeString(_ string: String) throws {
        writtenStrings.append(string)
    }
}

private struct FailingClipboardWriter: ClipboardWriting {
    func writeString(_ string: String) throws {
        throw TestError.expected
    }
}

private final class FakeLaunchAtLoginController: LaunchAtLoginControlling, @unchecked Sendable {
    var isEnabled = false
    var errorToThrow: Error?

    func setEnabled(_ enabled: Bool) throws {
        if let errorToThrow {
            throw errorToThrow
        }
        isEnabled = enabled
    }
}

@MainActor
private final class FakeFinderExtensionController: FinderExtensionManaging {
    var isEnabled = false
    private(set) var showManagementInterfaceCallCount = 0

    func showManagementInterface() {
        showManagementInterfaceCallCount += 1
    }
}

private enum TestError: Error {
    case expected
}
