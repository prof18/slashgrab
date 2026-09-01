import AppKit
import FinderSync
import SlashgrabCore

final class FinderSync: FIFinderSync {
    private let copyAction = PathCopyAction(
        clipboardWriter: FinderClipboardWriter(),
        historyStore: SharedSettings.makeStore()
    )
    private let pathFormatReader = SharedSettings.makePathFormatReader()

    override init() {
        super.init()

        // Monitoring the filesystem root makes the contextual command available for
        // local files, external volumes, and network mounts without inspecting files.
        FIFinderSyncController.default().directoryURLs = [
            URL(fileURLWithPath: "/", isDirectory: true),
        ]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems else {
            return nil
        }

        let menu = NSMenu(title: "Slashgrab")
        let copyItem = NSMenuItem(
            title: "Copy Path",
            action: #selector(copySelectedPaths),
            keyEquivalent: ""
        )
        copyItem.target = self
        menu.addItem(copyItem)
        return menu
    }

    @objc
    private func copySelectedPaths() {
        let controller = FIFinderSyncController.default()
        let selectedURLs = controller.selectedItemURLs() ?? []
        let urls = selectedURLs.isEmpty ? controller.targetedURL().map { [$0] } ?? [] : selectedURLs
        let format = pathFormatReader?.selectedFormat ?? .shellEscaped
        _ = try? copyAction.copy(urls: urls, as: format)
    }
}

private struct FinderClipboardWriter: ClipboardWriting {
    func writeString(_ string: String) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(string, forType: .string) else {
            throw FinderClipboardError.writeFailed
        }
    }
}

private enum FinderClipboardError: Error {
    case writeFailed
}
