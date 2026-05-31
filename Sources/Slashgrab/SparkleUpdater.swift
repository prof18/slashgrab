import Foundation
import Sparkle

@MainActor
protocol UpdaterControlling: AnyObject {
    var canCheckForUpdates: Bool { get }
    func checkForUpdates()
}

@MainActor
final class SparkleUpdater: NSObject, UpdaterControlling {
    private let controller: SPUStandardUpdaterController?

    override init() {
        if Bundle.main.nonEmptyInfoString("SUFeedURL") != nil,
           Bundle.main.nonEmptyInfoString("SUPublicEDKey") != nil {
            controller = SPUStandardUpdaterController(
                startingUpdater: false,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        } else {
            controller = nil
        }
        super.init()
        controller?.startUpdater()
    }

    var canCheckForUpdates: Bool {
        controller?.updater.canCheckForUpdates ?? false
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}

private extension Bundle {
    func nonEmptyInfoString(_ key: String) -> String? {
        guard let value = object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty else {
            return nil
        }
        return value
    }
}
