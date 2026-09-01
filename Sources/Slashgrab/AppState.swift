import Foundation
import SlashgrabCore

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var history: PathHistory
    @Published private(set) var feedback: DropFeedback?
    @Published var selectedFormat: PathFormat
    @Published private(set) var launchAtLoginEnabled: Bool
    @Published private(set) var finderExtensionEnabled: Bool

    private let settings: AppSettingsStore
    private let sharedSettings: AppSettingsStore?
    private let formatter: PathFormatter
    private let clipboardWriter: ClipboardWriting
    private let launchAtLoginController: LaunchAtLoginControlling
    private let finderExtensionController: FinderExtensionManaging
    private var feedbackTask: Task<Void, Never>?

    init(
        settings: AppSettingsStore,
        sharedSettings: AppSettingsStore? = nil,
        formatter: PathFormatter = PathFormatter(),
        clipboardWriter: ClipboardWriting = AppKitClipboardWriter(),
        launchAtLoginController: LaunchAtLoginControlling = LaunchAtLoginController(),
        finderExtensionController: FinderExtensionManaging = FinderExtensionController()
    ) {
        self.settings = settings
        self.sharedSettings = sharedSettings
        self.formatter = formatter
        self.clipboardWriter = clipboardWriter
        self.launchAtLoginController = launchAtLoginController
        self.finderExtensionController = finderExtensionController
        let storedFormat = settings.selectedFormat
        selectedFormat = storedFormat
        sharedSettings?.selectedFormat = storedFormat
        history = settings.loadHistory()
        let currentLaunchAtLoginEnabled = launchAtLoginController.isEnabled
        launchAtLoginEnabled = currentLaunchAtLoginEnabled
        finderExtensionEnabled = finderExtensionController.isEnabled
        settings.launchAtLoginEnabled = currentLaunchAtLoginEnabled
    }

    static func production() -> AppState {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.prof18.slashgrab.dev"
        let defaults = UserDefaults(suiteName: bundleIdentifier) ?? .standard
        return AppState(
            settings: AppSettingsStore(defaults: defaults),
            sharedSettings: SharedSettings.makeStore()
        )
    }

    var lastCopiedOutput: String? {
        history.entries.first
    }

    func setSelectedFormat(_ format: PathFormat) {
        selectedFormat = format
        settings.selectedFormat = format
        sharedSettings?.selectedFormat = format
    }

    @discardableResult
    func handleDroppedURLs(_ urls: [URL]) -> Bool {
        guard !urls.isEmpty else {
            showFeedback(.failure("Unsupported drop"))
            return false
        }

        let output = formatter.format(urls: urls, as: selectedFormat)
        return copyOutput(output, successMessage: "Path copied")
    }

    func copyAgain(_ output: String) {
        copyOutput(output, successMessage: "Copied again")
    }

    func clearHistory() {
        history.clear()
        settings.saveHistory(history)
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        do {
            try launchAtLoginController.setEnabled(enabled)
            launchAtLoginEnabled = launchAtLoginController.isEnabled
            settings.launchAtLoginEnabled = launchAtLoginEnabled
            showFeedback(launchAtLoginEnabled ? .success("Launch at login on") : .success("Launch at login off"))
        } catch {
            launchAtLoginEnabled = launchAtLoginController.isEnabled
            settings.launchAtLoginEnabled = launchAtLoginEnabled
            showFeedback(.failure("Launch at login failed"))
        }
    }

    func refreshFinderExtensionStatus() {
        finderExtensionEnabled = finderExtensionController.isEnabled
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = launchAtLoginController.isEnabled
        settings.launchAtLoginEnabled = launchAtLoginEnabled
    }

    func showFinderExtensionSettings() {
        finderExtensionController.showManagementInterface()
    }

    @discardableResult
    private func copyOutput(_ output: String, successMessage: String) -> Bool {
        do {
            try clipboardWriter.writeString(output)
            history.add(output)
            settings.saveHistory(history)
            showFeedback(.success(successMessage, detail: output))
            return true
        } catch {
            showFeedback(.failure("Clipboard write failed"))
            return false
        }
    }

    private func showFeedback(_ feedback: DropFeedback) {
        feedbackTask?.cancel()
        self.feedback = feedback
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.7))
            await MainActor.run {
                if !Task.isCancelled {
                    self?.feedback = nil
                }
            }
        }
    }
}

struct DropFeedback: Identifiable, Equatable {
    enum Kind: Equatable {
        case success
        case failure
    }

    let id = UUID()
    let kind: Kind
    let message: String
    let detail: String?

    static func success(_ message: String, detail: String? = nil) -> DropFeedback {
        DropFeedback(kind: .success, message: message, detail: detail)
    }

    static func failure(_ message: String) -> DropFeedback {
        DropFeedback(kind: .failure, message: message, detail: nil)
    }
}
