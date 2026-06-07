import AppKit

enum URLDropReader {
    struct Inspection {
        let urls: [URL]
        let canAccept: Bool
    }

    private static let legacyFilenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
    private static let publicFileURLType = NSPasteboard.PasteboardType("public.file-url")
    private static let publicURLType = NSPasteboard.PasteboardType("public.url")
    private static let promisedFileURLType = NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-url")

    private static let concreteURLTypes: [NSPasteboard.PasteboardType] = [
        .fileURL,
        .URL,
        publicFileURLType,
        publicURLType,
        promisedFileURLType,
    ]

    private static let fallbackFilePathTypes: [NSPasteboard.PasteboardType] = [
        .fileURL,
        publicFileURLType,
        promisedFileURLType,
        legacyFilenamesType,
    ]

    static let readableTypes: [NSPasteboard.PasteboardType] = [
        .fileURL,
        .URL,
        publicFileURLType,
        publicURLType,
        promisedFileURLType,
        legacyFilenamesType,
    ]

    static func canContainFileURLs(_ pasteboard: NSPasteboard) -> Bool {
        inspection(of: pasteboard).canAccept
    }

    static func inspection(of pasteboard: NSPasteboard) -> Inspection {
        let urls = fileURLs(from: pasteboard)
        if !urls.isEmpty {
            return Inspection(
                urls: urls,
                canAccept: true
            )
        }

        let directMatches = matchingFallbackTypeNames(in: pasteboard.types ?? [])
        if !directMatches.isEmpty {
            return Inspection(
                urls: [],
                canAccept: true
            )
        }

        let itemMatches = pasteboard.pasteboardItems?.enumerated().flatMap { index, item in
            matchingFallbackTypeNames(in: item.types).map { "item\(index):\($0)" }
        } ?? []
        if !itemMatches.isEmpty {
            return Inspection(
                urls: [],
                canAccept: true
            )
        }

        return Inspection(
            urls: [],
            canAccept: false
        )
    }

    static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        var urls: [URL] = []

        for type in concreteURLTypes {
            appendFileURLs(from: pasteboard.string(forType: type), to: &urls)
            appendFileURLs(from: pasteboard.data(forType: type), to: &urls)
            appendFileURLs(fromPropertyList: pasteboard.propertyList(forType: type), to: &urls)
        }
        if pasteboard.types?.contains(legacyFilenamesType) == true {
            appendFileURLs(fromPropertyList: pasteboard.propertyList(forType: legacyFilenamesType), to: &urls)
        }

        pasteboard.pasteboardItems?.forEach { item in
            urls.append(contentsOf: fileURLs(from: item))
        }

        var seenPaths = Set<String>()
        return urls.map(\.standardizedFileURL).filter { url in
            seenPaths.insert(url.path).inserted
        }
    }

    private static func fileURLs(from item: NSPasteboardItem) -> [URL] {
        var urls: [URL] = []

        for type in concreteURLTypes {
            appendFileURLs(from: item.string(forType: type), to: &urls)
            appendFileURLs(from: item.data(forType: type), to: &urls)
            appendFileURLs(fromPropertyList: item.propertyList(forType: type), to: &urls)
        }
        if item.types.contains(legacyFilenamesType) {
            appendFileURLs(fromPropertyList: item.propertyList(forType: legacyFilenamesType), to: &urls)
        }

        return urls
    }

    private static func appendFileURLs(from data: Data?, to urls: inout [URL]) {
        guard let data else {
            return
        }

        if let rawValue = String(data: data, encoding: .utf8) {
            appendFileURLs(from: rawValue, to: &urls)
        }

        if let propertyList = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) {
            appendFileURLs(fromPropertyList: propertyList, to: &urls)
        }
    }

    private static func appendFileURLs(from rawValue: String?, to urls: inout [URL]) {
        guard let rawValue,
              let url = fileURL(from: rawValue) else {
            return
        }

        urls.append(url)
    }

    private static func appendFileURLs(fromPropertyList propertyList: Any?, to urls: inout [URL]) {
        switch propertyList {
        case let rawValue as String:
            appendFileURLs(from: rawValue, to: &urls)
        case let values as [String]:
            values.forEach { appendFileURLs(from: $0, to: &urls) }
        case let url as URL where url.isFileURL:
            urls.append(url)
        case let nsURL as NSURL where nsURL.isFileURL:
            urls.append(nsURL as URL)
        case let data as Data:
            appendFileURLs(from: data, to: &urls)
        case let values as [Any]:
            values.forEach { appendFileURLs(fromPropertyList: $0, to: &urls) }
        default:
            break
        }
    }

    private static func fileURL(from rawValue: String) -> URL? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
        guard !value.isEmpty else {
            return nil
        }

        if let url = URL(string: value),
           url.isFileURL {
            return url
        }

        if value.hasPrefix("/") || value.hasPrefix("~/") {
            return URL(fileURLWithPath: NSString(string: value).expandingTildeInPath)
        }

        return nil
    }

    private static func matchingFallbackTypeNames(in types: [NSPasteboard.PasteboardType]) -> [String] {
        types.filter { fallbackFilePathTypes.contains($0) }.map(\.rawValue)
    }

}
