import Foundation

@MainActor
protocol UpdaterControlling: AnyObject {
    var canCheckForUpdates: Bool { get }
    func checkForUpdates()
}

@MainActor
final class SparkleUpdater: UpdaterControlling {
    var canCheckForUpdates: Bool {
        false
    }

    func checkForUpdates() {
        // Sparkle is wired in the release scaffold once the update key/feed exist.
    }
}
