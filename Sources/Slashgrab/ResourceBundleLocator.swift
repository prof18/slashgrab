import Foundation

enum ResourceBundleLocator {
    static var bundles: [Bundle] {
        candidateBundles() + [Bundle.main]
    }

    private static func candidateBundles() -> [Bundle] {
        let bundleName = "Slashgrab_Slashgrab.bundle"
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent(bundleName),
            Bundle.main.bundleURL.appendingPathComponent(bundleName),
        ].compactMap { $0 }

        var bundles: [Bundle] = []
        var seenPaths = Set<String>()

        for url in candidates {
            guard let bundle = Bundle(url: url) else {
                continue
            }

            let path = bundle.bundleURL.standardizedFileURL.path
            guard seenPaths.insert(path).inserted else {
                continue
            }

            bundles.append(bundle)
        }

        return bundles
    }
}
