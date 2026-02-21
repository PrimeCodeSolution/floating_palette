import Cocoa

/// Custom NSView that accepts first mouse click even when app is inactive.
/// This allows interacting with the panel in other Spaces or fullscreen apps.
class FirstMouseView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

/// Custom NSPanel that can become key window for keyboard input.
/// Regular borderless NSPanel returns false for canBecomeKey.
class KeyablePanel: NSPanel {
    /// When true, panel never takes keyboard focus (for auxiliary panels like virtual keyboard).
    /// Clicks still work but don't steal focus from other windows.
    var neverTakesFocus: Bool = false

    override var canBecomeKey: Bool { !neverTakesFocus }
    override var canBecomeMain: Bool { !neverTakesFocus }

    /// Palette ID for event emission
    var paletteId: String?

    /// Callback for focus events
    var onFocusChanged: ((String, Bool) -> Void)?

    /// Whether this panel supports user resizing
    var allowsUserResize: Bool = false

    /// Minimum size constraints for resizing
    var minResizeWidth: CGFloat = 100
    var minResizeHeight: CGFloat = 100

    /// Edge being resized (nil = not resizing)
    private var resizeEdge: ResizeEdge?
    private var resizeStartFrame: NSRect = .zero
    private var resizeStartMouse: NSPoint = .zero

    /// Resize hit zone width in points
    private let resizeHitZone: CGFloat = 6

    enum ResizeEdge {
        case left, right, top, bottom
        case topLeft, topRight, bottomLeft, bottomRight
    }

    /// When panel receives a mouse down, activate the app so we can interact.
    /// This helps with dragging in other Spaces/fullscreen.
    override func mouseDown(with event: NSEvent) {
        // Just pass to super - sendEvent handles focus restoration
        super.mouseDown(with: event)
    }

    /// Override to ensure mouse events reach us and Flutter gets focus.
    override func sendEvent(_ event: NSEvent) {
        // Handle resize for resizable borderless panels
        if allowsUserResize {
            switch event.type {
            case .mouseMoved, .mouseEntered, .mouseExited:
                updateResizeCursor(for: event)
            case .leftMouseDown:
                if let edge = edgeAt(event.locationInWindow) {
                    startResize(edge: edge, event: event)
                    return
                }
            case .leftMouseDragged:
                if resizeEdge != nil {
                    continueResize(event: event)
                    return
                }
            case .leftMouseUp:
                if resizeEdge != nil {
                    endResize()
                    return
                }
            default:
                break
            }
        }

        super.sendEvent(event)

        if event.type == .leftMouseDown && !neverTakesFocus {
            // Handle focus restoration asynchronously to not block event processing
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.neverTakesFocus else { return }

                // Ensure app is active
                if !NSApp.isActive {
                    NSApp.activate(ignoringOtherApps: true)
                }

                // Make panel key
                if !self.isKeyWindow {
                    self.makeKeyAndOrderFront(nil)
                }

                // Make Flutter view first responder
                if let flutterView = self.contentViewController?.view {
                    if self.firstResponder != flutterView {
                        self.makeFirstResponder(flutterView)
                    }
                }
            }
        }
    }

    // MARK: - Resize handling

    /// Determine which edge (if any) the point is near
    private func edgeAt(_ point: NSPoint) -> ResizeEdge? {
        let bounds = contentView?.bounds ?? .zero
        guard bounds.width > 0 && bounds.height > 0 else { return nil }

        // First check if point is within or very close to the window bounds
        // Allow a small margin outside for better edge detection UX
        let expandedBounds = bounds.insetBy(dx: -resizeHitZone, dy: -resizeHitZone)
        guard expandedBounds.contains(point) else { return nil }

        // Edge detection (6px from border)
        let nearLeft = point.x < resizeHitZone
        let nearRight = point.x > bounds.width - resizeHitZone
        let nearBottom = point.y < resizeHitZone  // macOS: Y=0 at bottom
        let nearTop = point.y > bounds.height - resizeHitZone

        // Corners (when near two edges simultaneously)
        if nearTop && nearLeft { return .topLeft }
        if nearTop && nearRight { return .topRight }
        if nearBottom && nearLeft { return .bottomLeft }
        if nearBottom && nearRight { return .bottomRight }

        // Edges
        if nearLeft { return .left }
        if nearRight { return .right }
        if nearTop { return .top }
        if nearBottom { return .bottom }

        return nil
    }

    // MARK: - Window resize cursors (using native macOS 15+ API)

    /// Get the appropriate resize cursor for the given edge
    /// Uses native frameResizeCursor API on macOS 15+, falls back to legacy cursors on older versions
    private func cursorForEdge(_ edge: ResizeEdge) -> NSCursor {
        if #available(macOS 15.0, *) {
            // Use .all so both triangles have the same color
            switch edge {
            case .left:
                return NSCursor.frameResize(position: .left, directions: .all)
            case .right:
                return NSCursor.frameResize(position: .right, directions: .all)
            case .top:
                return NSCursor.frameResize(position: .top, directions: .all)
            case .bottom:
                return NSCursor.frameResize(position: .bottom, directions: .all)
            case .topLeft:
                return NSCursor.frameResize(position: .topLeft, directions: .all)
            case .topRight:
                return NSCursor.frameResize(position: .topRight, directions: .all)
            case .bottomLeft:
                return NSCursor.frameResize(position: .bottomLeft, directions: .all)
            case .bottomRight:
                return NSCursor.frameResize(position: .bottomRight, directions: .all)
            }
        } else {
            // Fallback for older macOS versions
            switch edge {
            case .left, .right:
                return NSCursor.resizeLeftRight
            case .top, .bottom:
                return NSCursor.resizeUpDown
            case .topLeft, .topRight, .bottomLeft, .bottomRight:
                return NSCursor.arrow
            }
        }
    }

    /// Update cursor based on edge proximity
    private func updateResizeCursor(for event: NSEvent) {
        let point = event.locationInWindow
        guard let edge = edgeAt(point) else {
            NSCursor.arrow.set()
            return
        }
        cursorForEdge(edge).set()
    }

    private func startResize(edge: ResizeEdge, event: NSEvent) {
        resizeEdge = edge
        resizeStartFrame = frame
        resizeStartMouse = NSEvent.mouseLocation
    }

    private func continueResize(event: NSEvent) {
        guard let edge = resizeEdge else { return }

        let currentMouse = NSEvent.mouseLocation
        let deltaX = currentMouse.x - resizeStartMouse.x
        let deltaY = currentMouse.y - resizeStartMouse.y

        var newFrame = resizeStartFrame

        switch edge {
        case .right:
            newFrame.size.width += deltaX
        case .left:
            newFrame.origin.x += deltaX
            newFrame.size.width -= deltaX
        case .top:
            newFrame.size.height += deltaY
        case .bottom:
            newFrame.origin.y += deltaY
            newFrame.size.height -= deltaY
        case .topRight:
            newFrame.size.width += deltaX
            newFrame.size.height += deltaY
        case .topLeft:
            newFrame.origin.x += deltaX
            newFrame.size.width -= deltaX
            newFrame.size.height += deltaY
        case .bottomRight:
            newFrame.size.width += deltaX
            newFrame.origin.y += deltaY
            newFrame.size.height -= deltaY
        case .bottomLeft:
            newFrame.origin.x += deltaX
            newFrame.size.width -= deltaX
            newFrame.origin.y += deltaY
            newFrame.size.height -= deltaY
        }

        // Enforce minimum size from Dart config
        if newFrame.width >= minResizeWidth && newFrame.height >= minResizeHeight {
            setFrame(newFrame, display: true)

            // Update Flutter view to match new window size
            if let flutterView = contentViewController?.view {
                flutterView.frame = contentView?.bounds ?? .zero
            }
        }
    }

    private func endResize() {
        resizeEdge = nil
        NSCursor.arrow.set()
    }

    /// Called when panel becomes key window - emit focus event
    override func becomeKey() {
        super.becomeKey()
        if let id = paletteId {
            onFocusChanged?(id, true)
        }
    }

    /// Called when panel resigns key window - emit unfocus event.
    /// We skip super.resignKey() to prevent macOS from dimming the Liquid Glass
    /// effect when the app loses focus. The panel keeps its "key" appearance,
    /// which is correct for floating palettes (they should always look active).
    override func resignKey() {
        // Don't call super — keeps the panel's internal key state as true,
        // preventing SwiftUI/compositor from dimming the glass effect.
        // Focus events still fire so Dart side stays in sync.
        if let id = paletteId {
            onFocusChanged?(id, false)
        }
    }
}
