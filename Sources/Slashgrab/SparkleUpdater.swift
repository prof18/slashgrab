import Combine
import Foundation
import Sparkle

@MainActor
protocol UpdaterControlling: AnyObject, ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    var canCheckForUpdates: Bool { get }
    func checkForUpdates()
}

@MainActor
final class SparkleUpdater: NSObject, UpdaterControlling {
    @Published private(set) var canCheckForUpdates = false

    private let controller: SPUStandardUpdaterController?
    private var canCheckForUpdatesObservation: NSKeyValueObservation?

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

        if let controller {
            canCheckForUpdatesObservation = controller.updater.observe(
                \.canCheckForUpdates,
                options: [.initial, .new]
            ) { [weak self] _, change in
                guard let canCheckForUpdates = change.newValue else {
                    return
                }
                Task { @MainActor [weak self] in
                    self?.canCheckForUpdates = canCheckForUpdates
                }
            }
            controller.startUpdater()
        }
    }

    deinit {
        canCheckForUpdatesObservation?.invalidate()
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
