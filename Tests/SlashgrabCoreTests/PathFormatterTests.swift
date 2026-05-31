import Foundation
import Testing
@testable import SlashgrabCore

@Suite("Path formatter")
struct PathFormatterTests {
    private let formatter = PathFormatter(homeDirectory: URL(fileURLWithPath: "/Users/mg"))

    @Test("POSIX formatting leaves paths unchanged")
    func posixFormatting() {
        let url = URL(fileURLWithPath: "/Users/mg/Desktop/Test File.txt")
        #expect(formatter.format(url: url, as: .posix) == "/Users/mg/Desktop/Test File.txt")
    }

    @Test("Default shell escaped formatting escapes spaces")
    func shellEscapesSpaces() {
        let url = URL(fileURLWithPath: "/Users/mg/Desktop/Test File.txt")
        #expect(formatter.format(url: url, as: .shellEscaped) == "/Users/mg/Desktop/Test\\ File.txt")
    }

    @Test("Shell escaped formatting escapes quotes apostrophes and backslashes")
    func shellEscapesSpecialCharacters() {
        let url = URL(fileURLWithPath: "/Users/mg/Desktop/a \"quote\" and 'tick' \\ path.txt")
        #expect(formatter.format(url: url, as: .shellEscaped) == #"/Users/mg/Desktop/a\ \"quote\"\ and\ \'tick\'\ \\\ path.txt"#)
    }

    @Test("Shell escaped formatting uses ANSI-C quoting for newlines")
    func shellEscapesNewlines() {
        let url = URL(fileURLWithPath: "/Users/mg/Desktop/line\nbreak.txt")
        #expect(formatter.format(url: url, as: .shellEscaped) == "$'/Users/mg/Desktop/line\\nbreak.txt'")
    }

    @Test("Shell escaped multiple paths are terminal arguments")
    func shellEscapedMultiplePaths() {
        let urls = [
            URL(fileURLWithPath: "/Users/mg/Desktop/A.txt"),
            URL(fileURLWithPath: "/Users/mg/Desktop/Test File.txt"),
        ]
        #expect(formatter.format(urls: urls, as: .shellEscaped) == "/Users/mg/Desktop/A.txt /Users/mg/Desktop/Test\\ File.txt")
    }

    @Test("Double quoted paths escape quote-sensitive characters")
    func doubleQuotedFormatting() {
        let url = URL(fileURLWithPath: "/Users/mg/Desktop/$HOME \"note\".txt")
        #expect(formatter.format(url: url, as: .doubleQuoted) == "\"/Users/mg/Desktop/\\$HOME \\\"note\\\".txt\"")
    }

    @Test("File URL formatting percent encodes spaces")
    func fileURLFormatting() {
        let url = URL(fileURLWithPath: "/Users/mg/Desktop/Test File.txt")
        #expect(formatter.format(url: url, as: .fileURL) == "file:///Users/mg/Desktop/Test%20File.txt")
    }

    @Test("Tilde formatting shortens paths under the home directory")
    func tildeFormatting() {
        let url = URL(fileURLWithPath: "/Users/mg/Desktop/Test File.txt")
        #expect(formatter.format(url: url, as: .tilde) == "~/Desktop/Test File.txt")
    }

    @Test("List-style formats join multiple paths with newlines")
    func listStyleJoining() {
        let urls = [
            URL(fileURLWithPath: "/Users/mg/Desktop/A.txt"),
            URL(fileURLWithPath: "/Users/mg/Desktop/B.txt"),
        ]
        #expect(formatter.format(urls: urls, as: .posix) == "/Users/mg/Desktop/A.txt\n/Users/mg/Desktop/B.txt")
    }
}
