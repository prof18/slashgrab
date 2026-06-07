import Foundation

struct AppBuildInfo: Equatable {
    let bundleIdentifier: String
    let displayName: String
    let variant: String?

    var isDevBuild: Bool {
        if variant?.localizedCaseInsensitiveCompare("dev") == .orderedSame {
            return true
        }

        return bundleIdentifier.hasSuffix(".dev")
            || displayName.localizedCaseInsensitiveContains("dev")
    }

    static func current(bundle: Bundle = .main) -> AppBuildInfo {
        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Slashgrab"

        return AppBuildInfo(
            bundleIdentifier: bundle.bundleIdentifier ?? "com.prof18.slashgrab",
            displayName: displayName,
            variant: bundle.object(forInfoDictionaryKey: "SlashgrabBuildVariant") as? String
        )
    }
}
