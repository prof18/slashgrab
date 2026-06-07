import Foundation
import SlashgrabCore

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var history: PathHistory
    @Published private(set) var feedback: DropFeedback?
    @Published var selectedFormat: PathFormat
    @Published private(set) var launchAtLoginEnabled: Bool

    private let settings: AppSettingsStore
    private let formatter: PathFormatter
    private let clipboardWriter: ClipboardWriting
    private let launchAtLoginController: LaunchAtLoginControlling
    private var feedbackTask: Task<Void, Never>?

    init(
        settings: AppSettingsStore,
        formatter: PathFormatter = PathFormatter(),
        clipboardWriter: ClipboardWriting = AppKitClipboardWriter(),
        launchAtLoginController: LaunchAtLoginControlling = LaunchAtLoginController()
    ) {
        self.settings = settings
        self.formatter = formatter
        self.clipboardWriter = clipboardWriter
        self.launchAtLoginController = launchAtLoginController
        selectedFormat = settings.selectedFormat
        history = settings.loadHistory()
        launchAtLoginEnabled = launchAtLoginController.isEnabled || settings.launchAtLoginEnabled
    }

    static func production() -> AppState {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.prof18.slashgrab.dev"
        let defaults = UserDefaults(suiteName: bundleIdentifier) ?? .standard
        return AppState(settings: AppSettingsStore(defaults: defaults))
    }

    var lastCopiedOutput: String? {
        history.entries.first
    }

    func setSelectedFormat(_ format: PathFormat) {
        selectedFormat = format
        settings.selectedFormat = format
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
