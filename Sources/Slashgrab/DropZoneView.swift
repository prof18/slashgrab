import AppKit
import SwiftUI

struct DropZoneView: NSViewRepresentable {
    let onDrop: ([URL]) -> Void
    let onRejectedDrop: () -> Void

    func makeNSView(context: Context) -> DropZoneNSView {
        let view = DropZoneNSView()
        view.onDrop = onDrop
        view.onRejectedDrop = onRejectedDrop
        return view
    }

    func updateNSView(_ nsView: DropZoneNSView, context: Context) {
        nsView.onDrop = onDrop
        nsView.onRejectedDrop = onRejectedDrop
    }
}

final class DropZoneNSView: NSView {
    var onDrop: (([URL]) -> Void)?
    var onRejectedDrop: (() -> Void)?

    private var hovering = false {
        didSet {
            needsDisplay = true
        }
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

        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
        (hovering ? NSColor.controlAccentColor.withAlphaComponent(0.18) : NSColor.labelColor.withAlphaComponent(0.05)).setFill()
        path.fill()

        let border = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
        border.lineWidth = 1
        border.setLineDash([5, 4], count: 2, phase: 0)
        (hovering ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        border.stroke()

        let title = hovering ? "Release to copy path" : "Drop files or folders here"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: hovering ? NSColor.controlAccentColor : NSColor.secondaryLabelColor,
        ]
        let size = title.size(withAttributes: attributes)
        title.draw(
            at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2),
            withAttributes: attributes
        )
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let inspection = URLDropReader.inspection(of: sender.draggingPasteboard)
        hovering = inspection.canAccept
        SlashgrabLog.info(
            .dragDrop,
            "popover.dragEntered canAccept=\(inspection.canAccept) reason=\(inspection.reason); paths=\(inspection.pathSummary); pasteboard=\(inspection.pasteboardSummary)"
        )
        return hovering ? .copy : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let inspection = URLDropReader.inspection(of: sender.draggingPasteboard)
        SlashgrabLog.debug(.dragDrop, "popover.dragUpdated canAccept=\(inspection.canAccept) reason=\(inspection.reason); paths=\(inspection.pathSummary)")
        return inspection.canAccept ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        SlashgrabLog.info(.dragDrop, "popover.draggingExited")
        hovering = false
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let inspection = URLDropReader.inspection(of: sender.draggingPasteboard)
        SlashgrabLog.info(.dragDrop, "popover.prepareForDragOperation canPrepare=\(inspection.canAccept) reason=\(inspection.reason); paths=\(inspection.pathSummary)")
        return inspection.canAccept
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer {
            hovering = false
        }

        let inspection = URLDropReader.inspection(of: sender.draggingPasteboard)
        let urls = inspection.urls
        SlashgrabLog.info(
            .dragDrop,
            "popover.performDragOperation decodedCount=\(urls.count); reason=\(inspection.reason); paths=\(inspection.pathSummary); pasteboard=\(inspection.pasteboardSummary)"
        )
        guard !urls.isEmpty else {
            SlashgrabLog.warning(.dragDrop, "popover.performDragOperation rejected; no resolved URLs")
            onRejectedDrop?()
            return false
        }

        onDrop?(urls)
        SlashgrabLog.info(.dragDrop, "popover.performDragOperation handed off; count=\(urls.count)")
        return true
    }

    private func commonInit() {
        registerForDraggedTypes(URLDropReader.readableTypes)
        SlashgrabLog.debug(.dragDrop, "popover drop zone registered dragged types=\(URLDropReader.readableTypes.map(\.rawValue).joined(separator: ", "))")
        setAccessibilityRole(.button)
        setAccessibilityLabel("Slashgrab popover drop target")
    }
}
