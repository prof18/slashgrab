import Foundation

public struct PathFormatter: Sendable {
    private let homeDirectory: URL

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory.standardizedFileURL
    }

    public func format(urls: [URL], as pathFormat: PathFormat) -> String {
        urls.map { format(url: $0, as: pathFormat) }
            .joined(separator: pathFormat.multipleItemSeparator)
    }

    public func format(url: URL, as pathFormat: PathFormat) -> String {
        let path = url.standardizedFileURL.path
        switch pathFormat {
        case .shellEscaped:
            return shellEscape(path)
        case .posix:
            return path
        case .doubleQuoted:
            return doubleQuote(path)
        case .fileURL:
            return url.standardizedFileURL.absoluteString
        case .tilde:
            return tildePath(for: path)
        }
    }

    private func shellEscape(_ path: String) -> String {
        if path.contains(where: { $0.isNewline || $0.isASCIIControl }) {
            return ansiCQuote(path)
        }

        let safeScalars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/_-.,:=+@%")
        var output = ""
        for scalar in path.unicodeScalars {
            if safeScalars.contains(scalar) {
                output.unicodeScalars.append(scalar)
            } else {
                output.append("\\")
                output.unicodeScalars.append(scalar)
            }
        }
        return output
    }

    private func doubleQuote(_ path: String) -> String {
        var output = "\""
        for character in path {
            switch character {
            case "\\", "\"", "$", "`":
                output.append("\\")
                output.append(character)
            default:
                output.append(character)
            }
        }
        output.append("\"")
        return output
    }

    private func ansiCQuote(_ path: String) -> String {
        var output = "$'"
        for scalar in path.unicodeScalars {
            switch scalar {
            case "\n":
                output += "\\n"
            case "\r":
                output += "\\r"
            case "\t":
                output += "\\t"
            case "\\":
                output += "\\\\"
            case "'":
                output += "\\'"
            default:
                output.unicodeScalars.append(scalar)
            }
        }
        output.append("'")
        return output
    }

    private func tildePath(for path: String) -> String {
        let homePath = homeDirectory.path
        if path == homePath {
            return "~"
        }
        let prefix = homePath.hasSuffix("/") ? homePath : homePath + "/"
        guard path.hasPrefix(prefix) else {
            return path
        }
        return "~/" + path.dropFirst(prefix.count)
    }
}

private extension Character {
    var isASCIIControl: Bool {
        unicodeScalars.allSatisfy { $0.value < 32 || $0.value == 127 }
    }
}
