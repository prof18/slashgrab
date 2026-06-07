import AppKit
import SlashgrabCore

enum ClipboardWriteError: Error {
    case failed
}

struct AppKitClipboardWriter: ClipboardWriting {
    func writeString(_ string: String) throws {
        SlashgrabLog.info(.clipboard, "writeString attempting; length=\(string.count); lineCount=\(string.split(separator: "\n", omittingEmptySubsequences: false).count); value=\(string)")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(string, forType: .string) else {
            SlashgrabLog.error(.clipboard, "writeString failed; NSPasteboard.setString returned false")
            throw ClipboardWriteError.failed
        }
        SlashgrabLog.info(.clipboard, "writeString succeeded")
    }
}
