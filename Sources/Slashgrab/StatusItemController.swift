import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController {
    private let appState: AppState
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let feedbackPopover = NSPopover()
    private let updater = SparkleUpdater()
    private var statusView: DropTargetStatusView?
    private var feedbackDismissTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []

    init(appState: AppState) {
        self.appState = appState
    }

    func install() {
        let view = DropTargetStatusView(frame: NSRect(x: 0, y: 0, width: 32, height: NSStatusBar.system.thickness))
        view.onClick = { [weak self] in
            self?.togglePopover()
        }
        view.onDrop = { [weak appState] urls in
            appState?.handleDroppedURLs(urls)
        }
        view.onRejectedDrop = { [weak appState] in
            appState?.handleDroppedURLs([])
        }
        statusView = view
        statusItem.view = view

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 420)
        popover.contentViewController = NSHostingController(
            rootView: MenuPopoverView(
                appState: appState,
                updater: updater,
                onQuit: { NSApp.terminate(nil) }
            )
        )

        feedbackPopover.behavior = .transient
        feedbackPopover.contentSize = NSSize(width: 188, height: 46)

        appState.$feedback
            .compactMap { $0 }
            .sink { [weak self] feedback in
                self?.showFeedbackPopover(feedback)
            }
            .store(in: &cancellables)
    }

    private func togglePopover() {
        guard let statusView else {
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: statusView.bounds, of: statusView, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showFeedbackPopover(_ feedback: DropFeedback) {
        guard let statusView else {
            return
        }

        feedbackDismissTask?.cancel()

        if popover.isShown {
            feedbackPopover.performClose(nil)
        } else {
            feedbackPopover.contentViewController = NSHostingController(
                rootView: FeedbackPopoverView(feedback: feedback)
            )
            feedbackPopover.show(relativeTo: statusView.bounds, of: statusView, preferredEdge: .minY)
        }

        feedbackDismissTask = Task { [weak feedbackPopover] in
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run {
                if !Task.isCancelled {
                    feedbackPopover?.performClose(nil)
                }
            }
        }
    }
}
