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
            SlashgrabLog.warning(.appState, "handleDroppedURLs rejected empty URL list")
            showFeedback(.failure("Unsupported drop"))
            return false
        }

        SlashgrabLog.info(.appState, "handleDroppedURLs accepted count=\(urls.count); format=\(selectedFormat.rawValue); paths=\(URLDropReader.pathSummary(urls))")
        let output = formatter.format(urls: urls, as: selectedFormat)
        return copyOutput(output, successMessage: "Path copied")
    }

    func copyAgain(_ output: String) {
        SlashgrabLog.info(.appState, "copyAgain requested; outputLength=\(output.count); output=\(output)")
        copyOutput(output, successMessage: "Copied again")
    }

    func clearHistory() {
        SlashgrabLog.info(.appState, "clearHistory requested; previousCount=\(history.entries.count)")
        history.clear()
        settings.saveHistory(history)
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        SlashgrabLog.info(.appState, "setLaunchAtLoginEnabled requested enabled=\(enabled)")
        do {
            try launchAtLoginController.setEnabled(enabled)
            launchAtLoginEnabled = launchAtLoginController.isEnabled
            settings.launchAtLoginEnabled = launchAtLoginEnabled
            SlashgrabLog.info(.appState, "setLaunchAtLoginEnabled succeeded actualEnabled=\(launchAtLoginEnabled)")
            showFeedback(launchAtLoginEnabled ? .success("Launch at login on") : .success("Launch at login off"))
        } catch {
            launchAtLoginEnabled = launchAtLoginController.isEnabled
            settings.launchAtLoginEnabled = launchAtLoginEnabled
            SlashgrabLog.error(.appState, "setLaunchAtLoginEnabled failed actualEnabled=\(launchAtLoginEnabled); error=\(error.localizedDescription)")
            showFeedback(.failure("Launch at login failed"))
        }
    }

    @discardableResult
    private func copyOutput(_ output: String, successMessage: String) -> Bool {
        SlashgrabLog.info(.appState, "copyOutput attempting; message=\(successMessage); outputLength=\(output.count); output=\(output)")
        do {
            try clipboardWriter.writeString(output)
            history.add(output)
            settings.saveHistory(history)
            SlashgrabLog.info(.appState, "copyOutput succeeded; historyCount=\(history.entries.count)")
            showFeedback(.success(successMessage, detail: output))
            return true
        } catch {
            SlashgrabLog.error(.appState, "copyOutput failed; error=\(error.localizedDescription)")
            showFeedback(.failure("Clipboard write failed"))
            return false
        }
    }

    private func showFeedback(_ feedback: DropFeedback) {
        feedbackTask?.cancel()
        self.feedback = feedback
        SlashgrabLog.debug(.appState, "showFeedback kind=\(feedback.kind.logName); message=\(feedback.message); detail=\(feedback.detail ?? "none")")
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.7))
            await MainActor.run {
                if !Task.isCancelled {
                    SlashgrabLog.debug(.appState, "feedback auto-dismissed")
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

private extension DropFeedback.Kind {
    var logName: String {
        switch self {
        case .success:
            "success"
        case .failure:
            "failure"
        }
    }
}
