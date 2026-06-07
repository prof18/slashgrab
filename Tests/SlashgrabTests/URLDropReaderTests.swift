import AppKit
import Foundation
import Testing
@testable import Slashgrab

@Suite("URL drop reader")
struct URLDropReaderTests {
    @Test("Reads file URLs from pasteboard objects")
    func readsFileURLObjects() {
        let pasteboard = makePasteboard()
        let firstURL = URL(fileURLWithPath: "/tmp/Slashgrab Test/A.txt")
        let secondURL = URL(fileURLWithPath: "/tmp/Slashgrab Test/B.txt")
        pasteboard.writeObjects([firstURL as NSURL, secondURL as NSURL])

        let inspection = URLDropReader.inspection(of: pasteboard)

        #expect(inspection.canAccept)
        #expect(inspection.urls.map(\.path) == [
            "/tmp/Slashgrab Test/A.txt",
            "/tmp/Slashgrab Test/B.txt",
        ])
    }

    @Test("Reads file URL data")
    func readsFileURLData() {
        let pasteboard = makePasteboard()
        let fileURLType = NSPasteboard.PasteboardType("public.file-url")
        pasteboard.declareTypes([fileURLType], owner: nil)
        pasteboard.setData(
            Data("file:///tmp/Slashgrab%20Test/A.txt".utf8),
            forType: fileURLType
        )

        let inspection = URLDropReader.inspection(of: pasteboard)

        #expect(inspection.canAccept)
        #expect(inspection.urls.map(\.path) == ["/tmp/Slashgrab Test/A.txt"])
    }

    @Test("Deduplicates standardized file paths")
    func deduplicatesStandardizedPaths() {
        let pasteboard = makePasteboard()
        let fileURLType = NSPasteboard.PasteboardType("public.file-url")
        pasteboard.declareTypes([fileURLType], owner: nil)
        pasteboard.setString("file:///tmp/Slashgrab%20Test/../Slashgrab%20Test/A.txt", forType: fileURLType)

        let item = NSPasteboardItem()
        item.setString("/tmp/Slashgrab Test/A.txt", forType: fileURLType)
        pasteboard.writeObjects([item])

        let inspection = URLDropReader.inspection(of: pasteboard)

        #expect(inspection.canAccept)
        #expect(inspection.urls.map(\.path) == ["/tmp/Slashgrab Test/A.txt"])
    }

    @Test("Rejects non-file pasteboard data")
    func rejectsNonFilePasteboardData() {
        let pasteboard = makePasteboard()
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString("https://example.com/not-a-file", forType: .string)

        let inspection = URLDropReader.inspection(of: pasteboard)

        #expect(!inspection.canAccept)
        #expect(inspection.urls.isEmpty)
    }

    private func makePasteboard() -> NSPasteboard {
        let pasteboardName = NSPasteboard.Name("com.prof18.slashgrab.tests.\(UUID().uuidString)")
        let pasteboard = NSPasteboard(name: pasteboardName)
        pasteboard.clearContents()
        return pasteboard
    }
}
