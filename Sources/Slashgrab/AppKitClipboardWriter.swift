import AppKit
import SlashgrabCore

enum ClipboardWriteError: Error {
    case failed
}

struct AppKitClipboardWriter: ClipboardWriting {
    func writeString(_ string: String) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(string, forType: .string) else {
            throw ClipboardWriteError.failed
        }
    }
}
