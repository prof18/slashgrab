import AppKit

enum AppIconProvider {
    @MainActor
    static func image() -> NSImage {
        if let image = loadBundledAppIcon() {
            image.isTemplate = false
            return image
        }

        let image = NSApp.applicationIconImage ?? NSImage(size: NSSize(width: 128, height: 128))
        image.isTemplate = false
        return image
    }

    private static func loadBundledAppIcon() -> NSImage? {
        for bundle in ResourceBundleLocator.bundles {
            if let url = bundle.url(forResource: "AppIcon", withExtension: "icns"),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }

        return nil
    }
}
