import AppKit

final class DropTargetStatusView: NSView {
    enum VisualState {
        case idle
        case hovering
        case success
        case failure
    }

    var onClick: (() -> Void)?
    var onDrop: (([URL]) -> Void)?
    var onRejectedDrop: (() -> Void)?

    private var visualState: VisualState = .idle {
        didSet {
            needsDisplay = true
        }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 38, height: NSStatusBar.system.thickness)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rect = bounds.insetBy(dx: 3, dy: 3)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)

        switch visualState {
        case .idle:
            NSColor.clear.setFill()
        case .hovering:
            NSColor.controlAccentColor.withAlphaComponent(0.22).setFill()
        case .success:
            NSColor.systemGreen.withAlphaComponent(0.30).setFill()
        case .failure:
            NSColor.systemRed.withAlphaComponent(0.28).setFill()
        }
        path.fill()

        let slash = "/"
        let color: NSColor = switch visualState {
        case .failure:
            .systemRed
        case .success:
            .systemGreen
        default:
            .labelColor
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .bold),
            .foregroundColor: color,
        ]
        let size = slash.size(withAttributes: attributes)
        let origin = NSPoint(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2 - 1
        )
        slash.draw(at: origin, withAttributes: attributes)
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let urls = URLDropReader.fileURLs(from: sender.draggingPasteboard)
        if urls.isEmpty {
            visualState = .failure
            return []
        }
        visualState = .hovering
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        URLDropReader.fileURLs(from: sender.draggingPasteboard).isEmpty ? [] : .copy
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        !URLDropReader.fileURLs(from: sender.draggingPasteboard).isEmpty
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        visualState = .idle
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        scheduleIdleReset()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = URLDropReader.fileURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else {
            visualState = .failure
            onRejectedDrop?()
            scheduleIdleReset()
            return false
        }

        visualState = .success
        onDrop?(urls)
        scheduleIdleReset()
        return true
    }

    private func commonInit() {
        frame.size = intrinsicContentSize
        registerForDraggedTypes(URLDropReader.readableTypes)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Slashgrab path drop target")
    }

    private func scheduleIdleReset() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.visualState = .idle
        }
    }
}
