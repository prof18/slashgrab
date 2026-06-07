import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController {
    private let appState: AppState
    private let buildInfo = AppBuildInfo.current()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let feedbackPopover = NSPopover()
    private let dropReadyPopover = NSPopover()
    private let updater = SparkleUpdater()
    private var statusView: DropTargetStatusView?
    private var aboutWindowController: NSWindowController?
    private var dropReadyShowTask: DispatchWorkItem?
    private var feedbackDismissTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []

    init(appState: AppState) {
        self.appState = appState
    }

    func install() {
        guard let button = statusItem.button else {
            return
        }

        statusItem.length = buildInfo.isDevBuild ? NSStatusItem.variableLength : NSStatusItem.squareLength
        button.image = StatusIconProvider.image(for: .idle)
        button.image?.size = NSSize(width: 22, height: 22)
        button.title = buildInfo.isDevBuild ? " DEV" : ""
        button.toolTip = buildInfo.isDevBuild ? "Slashgrab Dev Build" : "Slashgrab"
        button.imagePosition = buildInfo.isDevBuild ? .imageLeft : .imageOnly
        button.contentTintColor = nil

        let view = DropTargetStatusView(frame: button.bounds)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.statusButton = button
        view.onClick = { [weak self] in
            self?.togglePopover()
        }
        view.onDragSessionStarted = { [weak self] in
            self?.prepareForStatusItemDrop()
        }
        view.onDropTargetArmed = { [weak self] in
            self?.showDropReadyCue()
        }
        view.onDropTargetDisarmed = { [weak self] in
            self?.hideDropReadyCue()
        }
        view.onDrop = { [weak appState] urls in
            return appState?.handleDroppedURLs(urls) ?? false
        }
        view.onRejectedDrop = { [weak appState] in
            appState?.handleDroppedURLs([])
        }
        button.addSubview(view, positioned: .above, relativeTo: nil)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            view.topAnchor.constraint(equalTo: button.topAnchor),
            view.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])

        statusView = view

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 292)
        popover.contentViewController = NSHostingController(
            rootView: MenuPopoverView(
                appState: appState,
                buildInfo: buildInfo,
                updater: updater,
                onAbout: { [weak self] in
                    self?.openAboutWindow()
                },
                onQuit: { NSApp.terminate(nil) }
            )
        )

        feedbackPopover.behavior = .transient
        feedbackPopover.contentSize = NSSize(width: 280, height: 66)

        dropReadyPopover.behavior = .transient
        dropReadyPopover.contentSize = NSSize(width: 280, height: 66)

        appState.$feedback
            .compactMap { $0 }
            .sink { [weak self] feedback in
                self?.showFeedbackPopover(feedback)
            }
            .store(in: &cancellables)
    }

    private func prepareForStatusItemDrop() {
        keepStatusViewOnTop()
        feedbackDismissTask?.cancel()
        hideDropReadyCue()
        feedbackPopover.performClose(nil)
        popover.performClose(nil)
    }

    private func togglePopover() {
        guard let anchorView = statusItem.button else {
            return
        }
        keepStatusViewOnTop()

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
            clearMenuPopoverFocus()
            DispatchQueue.main.async { [weak self] in
                self?.clearMenuPopoverFocus()
            }
            keepStatusViewOnTop()
        }
    }

    private func clearMenuPopoverFocus() {
        guard let window = popover.contentViewController?.view.window else {
            return
        }

        window.initialFirstResponder = nil
        window.makeFirstResponder(nil)
    }

    private func openAboutWindow() {
        popover.performClose(nil)

        if aboutWindowController == nil {
            let view = AboutView(
                buildInfo: buildInfo,
                canCheckForUpdates: updater.canCheckForUpdates,
                onCheckForUpdates: { [weak updater] in
                    updater?.checkForUpdates()
                }
            )
            let host = NSHostingController(rootView: view)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.contentViewController = host
            window.title = "About Slashgrab"
            window.minSize = NSSize(width: 560, height: 560)
            window.center()

            aboutWindowController = NSWindowController(window: window)
        }

        NSApp.activate(ignoringOtherApps: true)
        aboutWindowController?.showWindow(nil)
        aboutWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    private func showFeedbackPopover(_ feedback: DropFeedback) {
        guard let anchorView = statusItem.button else {
            return
        }

        feedbackDismissTask?.cancel()
        hideDropReadyCue()
        if feedbackPopover.isShown {
            feedbackPopover.performClose(nil)
        }

        if popover.isShown {
            feedbackPopover.performClose(nil)
        } else {
            feedbackPopover.contentViewController = NSHostingController(
                rootView: FeedbackPopoverView(feedback: feedback)
            )
            feedbackPopover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
            feedbackPopover.contentViewController?.view.window?.ignoresMouseEvents = true
        }

        feedbackDismissTask = Task { [weak feedbackPopover] in
            try? await Task.sleep(for: .seconds(1.7))
            await MainActor.run {
                if !Task.isCancelled {
                    feedbackPopover?.performClose(nil)
                }
            }
        }
    }

    private func showDropReadyCue() {
        guard let anchorView = statusItem.button,
              !popover.isShown,
              !dropReadyPopover.isShown else {
            return
        }

        dropReadyShowTask?.cancel()
        let task = DispatchWorkItem { [weak self, weak anchorView] in
            guard let self,
                  let anchorView,
                  !self.dropReadyPopover.isShown,
                  !self.popover.isShown else {
                return
            }

            self.showDropReadyPopover(relativeTo: anchorView)
        }
        dropReadyShowTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: task)
    }

    private func hideDropReadyCue() {
        dropReadyShowTask?.cancel()
        dropReadyShowTask = nil
        dropReadyPopover.performClose(nil)
    }

    private func showDropReadyPopover(relativeTo anchorView: NSView) {
        dropReadyPopover.contentViewController = NSHostingController(rootView: DropReadyPopoverView())
        dropReadyPopover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
        dropReadyPopover.contentViewController?.view.window?.ignoresMouseEvents = true
    }

    private func keepStatusViewOnTop() {
        guard let statusView,
              let button = statusItem.button,
              statusView.superview === button else {
            return
        }

        statusView.layer?.zPosition = CGFloat.greatestFiniteMagnitude
    }
}
