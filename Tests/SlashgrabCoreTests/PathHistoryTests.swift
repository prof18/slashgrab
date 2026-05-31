import Testing
@testable import SlashgrabCore

@Suite("Path history")
struct PathHistoryTests {
    @Test("History stores newest output first")
    func newestFirst() {
        var history = PathHistory(limit: 10)
        history.add("one")
        history.add("two")
        #expect(history.entries == ["two", "one"])
    }

    @Test("History caps stored entries")
    func capsEntries() {
        var history = PathHistory(limit: 2)
        history.add("one")
        history.add("two")
        history.add("three")
        #expect(history.entries == ["three", "two"])
    }

    @Test("Duplicate entries move to the top")
    func duplicateMovesToTop() {
        var history = PathHistory(entries: ["three", "two", "one"], limit: 10)
        history.add("one")
        #expect(history.entries == ["one", "three", "two"])
    }

    @Test("Empty outputs are ignored")
    func ignoresEmptyOutput() {
        var history = PathHistory(entries: ["one"], limit: 10)
        history.add("")
        #expect(history.entries == ["one"])
    }
}
