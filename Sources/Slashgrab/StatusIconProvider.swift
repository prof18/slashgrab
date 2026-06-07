import AppKit

enum StatusIconProvider {
    enum Kind {
        case idle
        case active
        case success

        var resourceName: String {
            switch self {
            case .idle:
                "SlashgrabStatusIdle"
            case .active:
                "SlashgrabStatusActive"
            case .success:
                "SlashgrabStatusSuccess"
            }
        }

        var fallbackName: String {
            switch self {
            case .idle:
                "SlashgrabStatusIdleTemplate"
            case .active:
                "SlashgrabStatusActiveTemplate"
            case .success:
                "SlashgrabStatusSuccessTemplate"
            }
        }
    }

    static func image(for kind: Kind) -> NSImage {
        let image = loadImage(kind) ?? drawFallback(kind)
        image.isTemplate = true
        image.size = NSSize(width: 22, height: 22)
        return image
    }

    private static func loadImage(_ kind: Kind) -> NSImage? {
        let bundles: [Bundle] = [Bundle.module, .main]
        for bundle in bundles {
            if let url = resourceURL(
                in: bundle,
                name: kind.resourceName,
                extension: "svg"
            ), let image = NSImage(contentsOf: url) {
                return image
            }

            if let url = resourceURL(
                in: bundle,
                name: kind.fallbackName,
                extension: "png"
            ), let image = NSImage(contentsOf: url) {
                return image
            }
        }

        return nil
    }

    private static func resourceURL(in bundle: Bundle, name: String, extension fileExtension: String) -> URL? {
        bundle.url(forResource: name, withExtension: fileExtension, subdirectory: "StatusIcons")
            ?? bundle.url(forResource: name, withExtension: fileExtension)
    }

    private static func drawFallback(_ kind: Kind) -> NSImage {
        NSImage(size: NSSize(width: 22, height: 22), flipped: false) { _ in
            NSColor.black.setStroke()

            let token = NSBezierPath(
                roundedRect: NSRect(x: 2.6, y: 5.6, width: 16.8, height: 10.8),
                xRadius: 2.6,
                yRadius: 2.6
            )
            token.lineWidth = kind == .active ? 1.9 : 1.7
            token.stroke()

            switch kind {
            case .success:
                let check = NSBezierPath()
                check.move(to: NSPoint(x: 8.3, y: 11.2))
                check.line(to: NSPoint(x: 10.1, y: 13.2))
                check.line(to: NSPoint(x: 13.9, y: 8.4))
                check.lineWidth = 2.2
                check.lineCapStyle = .round
                check.lineJoinStyle = .round
                check.stroke()
            case .idle, .active:
                let slash = NSBezierPath()
                slash.move(to: NSPoint(x: 8.9, y: 13.9))
                slash.line(to: NSPoint(x: 13.1, y: 8.1))
                slash.lineWidth = kind == .active ? 2.7 : 2.2
                slash.lineCapStyle = .round
                slash.stroke()
            }

            return true
        }
    }
}
