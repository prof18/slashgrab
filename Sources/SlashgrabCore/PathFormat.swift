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
            "Shell escaped"
        case .posix:
            "POSIX path"
        case .doubleQuoted:
            "Double quoted"
        case .fileURL:
            "File URL"
        case .tilde:
            "Tilde path"
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
