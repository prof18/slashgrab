import AppKit

enum URLDropReader {
    static let readableTypes: [NSPasteboard.PasteboardType] = [
        .fileURL,
        .URL,
        NSPasteboard.PasteboardType("public.file-url"),
        NSPasteboard.PasteboardType("NSFilenamesPboardType"),
    ]

    static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
        ]
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
           !urls.isEmpty {
            return urls.map(\.standardizedFileURL)
        }

        if let filenames = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String],
           !filenames.isEmpty {
            return filenames.map { URL(fileURLWithPath: $0).standardizedFileURL }
        }

        return pasteboard.pasteboardItems?.compactMap { item in
            guard let rawValue = item.string(forType: .fileURL),
                  let url = URL(string: rawValue),
                  url.isFileURL else {
                return nil
            }
            return url.standardizedFileURL
        } ?? []
    }
}
