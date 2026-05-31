import Foundation

public protocol ClipboardWriting: Sendable {
    func writeString(_ string: String) throws
}

public final class RecordingClipboardWriter: ClipboardWriting, @unchecked Sendable {
    public private(set) var lastString: String?

    public init() {}

    public func writeString(_ string: String) {
        lastString = string
    }
}
