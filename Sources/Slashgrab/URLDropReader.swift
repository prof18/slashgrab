import AppKit

enum URLDropReader {
    static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
        ]
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
           !urls.isEmpty {
            return urls.map(\.standardizedFileURL)
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
