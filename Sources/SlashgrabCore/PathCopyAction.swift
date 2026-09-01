import Foundation

public struct PathCopyAction: Sendable {
    private let formatter: PathFormatter
    private let clipboardWriter: ClipboardWriting
    private let historyStore: AppSettingsStore?

    public init(
        formatter: PathFormatter = PathFormatter(),
        clipboardWriter: ClipboardWriting,
        historyStore: AppSettingsStore? = nil
    ) {
        self.formatter = formatter
        self.clipboardWriter = clipboardWriter
        self.historyStore = historyStore
    }

    @discardableResult
    public func copy(urls: [URL], as format: PathFormat) throws -> String? {
        guard !urls.isEmpty else {
            return nil
        }

        let output = formatter.format(urls: urls, as: format)
        try clipboardWriter.writeString(output)
        historyStore?.addHistoryEntry(output)
        return output
    }
}
