import Foundation
import Testing
@testable import SlashgrabCore

@Suite("Path copy action")
struct PathCopyActionTests {
    @Test("Copies formatted paths to the clipboard")
    func copiesFormattedPaths() throws {
        let clipboard = RecordingClipboardWriter()
        let action = PathCopyAction(
            formatter: PathFormatter(homeDirectory: URL(fileURLWithPath: "/Users/mg")),
            clipboardWriter: clipboard
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
    }

    @Test("Empty selections do not change the clipboard")
    func ignoresEmptySelections() throws {
        let clipboard = RecordingClipboardWriter()
        let action = PathCopyAction(clipboardWriter: clipboard)

        let output = try action.copy(urls: [], as: .posix)

        #expect(output == nil)
        #expect(clipboard.lastString == nil)
    }
}
