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
        history = Self.mergedHistory(
            newest: sharedSettings?.loadHistory(),
            existing: settings.loadHistory(),
            limit: settings.historyLimit
        )
        let currentLaunchAtLoginEnabled = launchAtLoginController.isEnabled
        launchAtLoginEnabled = currentLaunchAtLoginEnabled
        finderExtensionEnabled = finderExtensionController.isEnabled
        settings.launchAtLoginEnabled = currentLaunchAtLoginEnabled
        persistHistory()
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

    func refreshHistory() {
        guard let sharedSettings else {
            history = settings.loadHistory()
            return
        }

        let sharedHistory = sharedSettings.loadHistory()
        guard sharedHistory != history else {
            return
        }

        history = Self.mergedHistory(
            newest: sharedHistory,
            existing: history,
            limit: settings.historyLimit
        )
        persistHistory()
    }

    func clearHistory() {
        history.clear()
        persistHistory()
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
            refreshHistory()
            history.add(output)
            persistHistory()
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

    private func persistHistory() {
        settings.saveHistory(history)
        sharedSettings?.saveHistory(history)
    }

    private static func mergedHistory(
        newest: PathHistory?,
        existing: PathHistory,
        limit: Int
    ) -> PathHistory {
        var entries: [String] = []
        for entry in (newest?.entries ?? []) + existing.entries where !entries.contains(entry) {
            entries.append(entry)
        }
        return PathHistory(entries: entries, limit: limit)
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
