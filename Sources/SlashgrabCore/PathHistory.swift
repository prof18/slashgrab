import Foundation

public struct PathHistory: Equatable, Sendable {
    public private(set) var entries: [String]
    public var limit: Int

    public init(entries: [String] = [], limit: Int = 10) {
        self.limit = max(1, limit)
        self.entries = Array(entries.prefix(self.limit))
    }

    public mutating func add(_ output: String) {
        guard !output.isEmpty else {
            return
        }
        entries.removeAll { $0 == output }
        entries.insert(output, at: 0)
        if entries.count > limit {
            entries.removeLast(entries.count - limit)
        }
    }

    public mutating func clear() {
        entries.removeAll()
    }
}
