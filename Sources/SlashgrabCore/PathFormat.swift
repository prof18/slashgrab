import Foundation

public enum PathFormat: String, CaseIterable, Codable, Identifiable, Sendable {
    case shellEscaped
    case posix
    case doubleQuoted
    case fileURL
    case tilde

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .shellEscaped:
            "Shell Escaped"
        case .posix:
            "Path"
        case .doubleQuoted:
            "Quoted Path"
        case .fileURL:
            "File URL"
        case .tilde:
            "Home-relative Path"
        }
    }

    public var multipleItemSeparator: String {
        switch self {
        case .shellEscaped, .doubleQuoted:
            " "
        case .posix, .fileURL, .tilde:
            "\n"
        }
    }
}
