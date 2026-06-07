import AppKit
import QuartzCore

final class DropTargetStatusView: NSView {
    var onClick: (() -> Void)?
    var onDragSessionStarted: (() -> Void)?
    var onDropTargetArmed: (() -> Void)?
    var onDropTargetDisarmed: (() -> Void)?
    var onDrop: (([URL]) -> Bool)?
    var onRejectedDrop: (() -> Void)?

    weak var statusButton: NSStatusBarButton? {
        didSet {
            configureStatusButton()
        }
    }

    private var resetWorkItem: DispatchWorkItem?
    private var dropAnimationInFlight = false
    private var isDropTargetArmed = false
    private var dragExitedArmedTarget = false
    private var lastAcceptedDragTime: CFTimeInterval?
    private var lastDragLocation: NSPoint?
    private var cachedDragURLs: [URL] = []
    private let dragEndRecoveryInterval: CFTimeInterval = 0.18
    private let dragEndRecoveryHalo: CGFloat = 24

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func accessibilityPerformPress() -> Bool {
        onClick?()
        return true
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDragSessionStarted?()

        let inspection = URLDropReader.inspection(of: sender.draggingPasteboard)

        guard inspection.canAccept else {
            resetDragSession()
            onDropTargetDisarmed?()
            showRejectedAnimation()
            return []
        }

        rememberAcceptedDrag(sender, urls: inspection.urls)
        showHover()
        onDropTargetArmed?()
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let inspection = URLDropReader.inspection(of: sender.draggingPasteboard)
        if !inspection.urls.isEmpty {
            rememberAcceptedDrag(sender, urls: inspection.urls)
            return .copy
        }

        guard isDropTargetArmed || inspection.canAccept else {
            resetDragSession()
            onDropTargetDisarmed?()
            return []
        }

        rememberAcceptedDrag(sender, urls: [])
        return .copy
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let inspection = URLDropReader.inspection(of: sender.draggingPasteboard)
        let canPrepare = isDropTargetArmed || inspection.canAccept
        return canPrepare
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        if let sender {
            lastDragLocation = sender.draggingLocation
        }
        dragExitedArmedTarget = isDropTargetArmed || !cachedDragURLs.isEmpty
        isDropTargetArmed = false
        onDropTargetDisarmed?()
        showIdle(animated: true)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        lastDragLocation = sender.draggingLocation

        if recoverDropFromDragEndedIfNeeded(sender) {
            return
        }

        resetDragSession()
        onDropTargetDisarmed?()
        if !dropAnimationInFlight {
            scheduleIdleReset(after: 0.12)
        }
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let inspection = URLDropReader.inspection(of: sender.draggingPasteboard)
        let droppedURLs = inspection.urls.isEmpty ? cachedDragURLs : inspection.urls
        return completeDrop(droppedURLs)
    }

    private func commonInit() {
        wantsLayer = true
        layer?.zPosition = 999
        registerForDraggedTypes(URLDropReader.readableTypes)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Slashgrab path drop target")
    }

    private func configureStatusButton() {
        guard let button = statusButton else {
            return
        }

        button.image = StatusIconProvider.image(for: .idle)
        button.image?.size = NSSize(width: 22, height: 22)
        if button.title.isEmpty {
            button.imagePosition = .imageOnly
        } else {
            button.imagePosition = .imageLeft
        }
        button.contentTintColor = nil
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        button.layer?.masksToBounds = false
        button.layer?.backgroundColor = NSColor.clear.cgColor
    }

    private func showHover() {
        resetWorkItem?.cancel()
        dropAnimationInFlight = false
        resetStatusButtonLayer()
        statusButton?.image = StatusIconProvider.image(for: .idle)
        statusButton?.contentTintColor = .controlAccentColor
        animateHighlight(to: NSColor.controlAccentColor.withAlphaComponent(0.08), duration: 0.14)
        animateScale(to: 1.02, duration: 0.14)
    }

    private func showSuccessAnimation() {
        resetWorkItem?.cancel()
        dropAnimationInFlight = true
        resetStatusButtonLayer()
        statusButton?.image = StatusIconProvider.image(for: .success)
        statusButton?.contentTintColor = .controlAccentColor
        animateHighlight(to: NSColor.controlAccentColor.withAlphaComponent(0.06), duration: 0.10)

        let pop = CAKeyframeAnimation(keyPath: "transform.scale")
        pop.values = [0.96, 1.06, 1.0]
        pop.keyTimes = [0.0, 0.45, 1.0]
        pop.duration = 0.34
        pop.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
        ]
        statusButton?.layer?.add(pop, forKey: "slashgrab.successPop")
        statusButton?.layer?.setAffineTransform(.identity)

        scheduleIdleReset(after: 0.48)
    }

    private func showRejectedAnimation() {
        resetWorkItem?.cancel()
        dropAnimationInFlight = true
        resetStatusButtonLayer()
        statusButton?.image = StatusIconProvider.image(for: .idle)
        statusButton?.contentTintColor = .systemRed
        animateHighlight(to: NSColor.systemRed.withAlphaComponent(0.18), duration: 0.08)
        animateScale(to: 1.0, duration: 0.08)

        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.values = [0, -2, 2, -1.5, 1.5, 0]
        shake.keyTimes = [0, 0.16, 0.34, 0.52, 0.72, 1]
        shake.duration = 0.42
        shake.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        shake.isAdditive = true
        statusButton?.layer?.add(shake, forKey: "slashgrab.rejectShake")

        scheduleIdleReset(after: 0.42)
    }

    private func showIdle(animated: Bool) {
        resetWorkItem?.cancel()
        dropAnimationInFlight = false
        statusButton?.layer?.removeAnimation(forKey: "slashgrab.successPop")
        statusButton?.layer?.removeAnimation(forKey: "slashgrab.rejectShake")
        statusButton?.image = StatusIconProvider.image(for: .idle)
        statusButton?.contentTintColor = nil
        animateHighlight(to: .clear, duration: animated ? 0.14 : 0)
        animateScale(to: 1.0, duration: animated ? 0.14 : 0)
    }

    private func animateHighlight(to color: NSColor, duration: CFTimeInterval) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        statusButton?.layer?.backgroundColor = color.cgColor
        CATransaction.commit()
    }

    private func animateScale(to scale: CGFloat, duration: CFTimeInterval) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        statusButton?.layer?.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        CATransaction.commit()
    }

    private func resetStatusButtonLayer() {
        statusButton?.layer?.removeAllAnimations()
        statusButton?.layer?.setAffineTransform(.identity)
    }

    private func rememberAcceptedDrag(_ sender: NSDraggingInfo, urls: [URL]) {
        if !urls.isEmpty {
            cachedDragURLs = urls
        }
        isDropTargetArmed = true
        dragExitedArmedTarget = false
        lastAcceptedDragTime = CACurrentMediaTime()
        lastDragLocation = sender.draggingLocation
    }

    private func recoverDropFromDragEndedIfNeeded(_ sender: NSDraggingInfo) -> Bool {
        guard !dropAnimationInFlight,
              !cachedDragURLs.isEmpty,
              isDropTargetArmed || dragExitedArmedTarget else {
            return false
        }

        let now = CACurrentMediaTime()
        let age = lastAcceptedDragTime.map { now - $0 } ?? .infinity
        let location = sender.draggingLocation
        let recoveryBounds = bounds.insetBy(dx: -dragEndRecoveryHalo, dy: -dragEndRecoveryHalo)
        let isNearTarget = recoveryBounds.contains(location)

        guard age <= dragEndRecoveryInterval, isNearTarget else {
            return false
        }

        _ = completeDrop(cachedDragURLs)
        return true
    }

    @discardableResult
    private func completeDrop(_ urls: [URL]) -> Bool {
        defer {
            resetDragSession()
        }

        guard !urls.isEmpty else {
            onRejectedDrop?()
            onDropTargetDisarmed?()
            showRejectedAnimation()
            return false
        }

        let succeeded = onDrop?(urls) ?? false
        onDropTargetDisarmed?()
        if succeeded {
            showSuccessAnimation()
        } else {
            showRejectedAnimation()
        }
        return succeeded
    }

    private func resetDragSession() {
        isDropTargetArmed = false
        dragExitedArmedTarget = false
        lastAcceptedDragTime = nil
        lastDragLocation = nil
        cachedDragURLs = []
    }

    private func scheduleIdleReset(after delay: TimeInterval) {
        resetWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.showIdle(animated: true)
        }
        resetWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
}
