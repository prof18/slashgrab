import Foundation
import OSLog

enum SlashgrabLog {
    enum Category {
        case appState
        case clipboard
        case dragDrop
        case pasteboard
        case statusItem
    }

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.prof18.slashgrab"

    private static let appState = Logger(subsystem: subsystem, category: "AppState")
    private static let clipboard = Logger(subsystem: subsystem, category: "Clipboard")
    private static let dragDrop = Logger(subsystem: subsystem, category: "DragDrop")
    private static let pasteboard = Logger(subsystem: subsystem, category: "Pasteboard")
    private static let statusItem = Logger(subsystem: subsystem, category: "StatusItem")

    static func debug(_ category: Category, _ message: String) {
        logger(for: category).debug("\(message, privacy: .public)")
    }

    static func info(_ category: Category, _ message: String) {
        logger(for: category).info("\(message, privacy: .public)")
    }

    static func warning(_ category: Category, _ message: String) {
        logger(for: category).warning("\(message, privacy: .public)")
    }

    static func error(_ category: Category, _ message: String) {
        logger(for: category).error("\(message, privacy: .public)")
    }

    private static func logger(for category: Category) -> Logger {
        switch category {
        case .appState:
            appState
        case .clipboard:
            clipboard
        case .dragDrop:
            dragDrop
        case .pasteboard:
            pasteboard
        case .statusItem:
            statusItem
        }
    }
}
