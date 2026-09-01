import Foundation

public struct PathCopyAction: Sendable {
    private let formatter: PathFormatter
    private let clipboardWriter: ClipboardWriting

    public init(
        formatter: PathFormatter = PathFormatter(),
        clipboardWriter: ClipboardWriting
    ) {
        self.formatter = formatter
        self.clipboardWriter = clipboardWriter
    }

    @discardableResult
    public func copy(urls: [URL], as format: PathFormat) throws -> String? {
        guard !urls.isEmpty else {
            return nil
        }

        let output = formatter.format(urls: urls, as: format)
        try clipboardWriter.writeString(output)
        return output
    }
}
