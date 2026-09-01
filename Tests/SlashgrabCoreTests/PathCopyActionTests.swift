import Foundation
import Testing
@testable import SlashgrabCore

@Suite("Path copy action")
struct PathCopyActionTests {
    @Test("Copies formatted paths to the clipboard")
    func copiesFormattedPaths() throws {
        let clipboard = RecordingClipboardWriter()
        let historyStore = AppSettingsStore(defaults: makeDefaults())
        let action = PathCopyAction(
            formatter: PathFormatter(homeDirectory: URL(fileURLWithPath: "/Users/mg")),
            clipboardWriter: clipboard,
            historyStore: historyStore
        )

        let output = try action.copy(
            urls: [
                URL(fileURLWithPath: "/Users/mg/Desktop/One.txt"),
                URL(fileURLWithPath: "/Users/mg/Desktop/Two.txt"),
            ],
            as: .posix
        )

        #expect(output == "/Users/mg/Desktop/One.txt\n/Users/mg/Desktop/Two.txt")
        #expect(clipboard.lastString == output)
        #expect(historyStore.loadHistory().entries == ["/Users/mg/Desktop/One.txt\n/Users/mg/Desktop/Two.txt"])
    }

    @Test("Empty selections do not change the clipboard")
    func ignoresEmptySelections() throws {
        let clipboard = RecordingClipboardWriter()
        let action = PathCopyAction(clipboardWriter: clipboard)

        let output = try action.copy(urls: [], as: .posix)

        #expect(output == nil)
        #expect(clipboard.lastString == nil)
    }

    @Test("Clipboard failures do not add history")
    func clipboardFailuresDoNotAddHistory() {
        let historyStore = AppSettingsStore(defaults: makeDefaults())
        let action = PathCopyAction(
            clipboardWriter: FailingClipboardWriter(),
            historyStore: historyStore
        )

        #expect(throws: CopyActionTestError.expected) {
            try action.copy(
                urls: [URL(fileURLWithPath: "/Users/mg/Desktop/One.txt")],
                as: .posix
            )
        }
        #expect(historyStore.loadHistory().entries.isEmpty)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "com.prof18.slashgrab.copy-action-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private struct FailingClipboardWriter: ClipboardWriting {
    func writeString(_ string: String) throws {
        throw CopyActionTestError.expected
    }
}

private enum CopyActionTestError: Error {
    case expected
}
