import Cocoa
import os.log

protocol DragCoordinatorDelegate: AnyObject {
    func dragBegan(_ id: String)
    func dragMoved(_ id: String, frame: NSRect)
    func dragEnded(_ id: String, frame: NSRect)
}

/// Owns the entire drag lifecycle for palette windows.
///
/// Implements custom drag handling instead of performDrag to get
/// real-time move callbacks during the drag operation.
final class DragCoordinator {
    private let store = WindowStore.shared
    weak var delegate: DragCoordinatorDelegate?

    /// Currently active drag session
    private var activeDrag: DragSession?

    /// Mouse event monitors for custom drag
    private var localMonitor: Any?
    private var globalMonitor: Any?

    struct DragSession {
        let windowId: String
        let panel: NSPanel
        let initialMouseLocation: NSPoint  // Screen coordinates
        let initialWindowOrigin: NSPoint
        var lastFrame: NSRect
    }

    /// Start a drag session. Called from FrameService startDrag command.
    func startDrag(_ id: String, window: PaletteWindow) {
        guard activeDrag == nil else {
            os_log("startDrag ignored: already dragging", log: Log.frame, type: .debug)
            return
        }

        guard window.draggable else {
            os_log("startDrag ignored: dragging disabled for %{public}@", log: Log.frame, type: .debug, id)
            return
        }

        guard let event = NSApp.currentEvent else {
            os_log("startDrag failed: no current event", log: Log.frame, type: .error)
            return
        }

        // Ensure app is active
        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
        }

        let panel = window.panel
        let mouseLocation = NSEvent.mouseLocation  // Screen coordinates
        let windowOrigin = panel.frame.origin

        activeDrag = DragSession(
            windowId: id,
            panel: panel,
            initialMouseLocation: mouseLocation,
            initialWindowOrigin: windowOrigin,
            lastFrame: panel.frame
        )

        os_log("dragBegan id=%{public}@ mouse=%{public}@ origin=%{public}@",
               log: Log.frame, type: .debug, id,
               NSStringFromPoint(mouseLocation),
               NSStringFromPoint(windowOrigin))
        delegate?.dragBegan(id)

        // Set up mouse monitors for custom drag handling
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] event in
            self?.handleMouseEvent(event, id: id)
            return event
        }

        // Global monitor catches events when mouse moves outside app windows
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] event in
            self?.handleMouseEvent(event, id: id)
        }
    }

    private func handleMouseEvent(_ event: NSEvent, id: String) {
        guard var session = activeDrag, session.windowId == id else { return }

        switch event.type {
        case .leftMouseDragged:
            // Calculate new window position based on mouse delta
            let currentMouse = NSEvent.mouseLocation
            let deltaX = currentMouse.x - session.initialMouseLocation.x
            let deltaY = currentMouse.y - session.initialMouseLocation.y

            let newOrigin = NSPoint(
                x: session.initialWindowOrigin.x + deltaX,
                y: session.initialWindowOrigin.y + deltaY
            )

            // Move the window
            session.panel.setFrameOrigin(newOrigin)

            let newFrame = session.panel.frame

            // Only notify if frame actually changed
            if newFrame != session.lastFrame {
                session.lastFrame = newFrame
                activeDrag = session

                os_log("dragMoved id=%{public}@ frame=%{public}@",
                       log: Log.frame, type: .debug, id, NSStringFromRect(newFrame))
                delegate?.dragMoved(id, frame: newFrame)
            }

        case .leftMouseUp:
            endDrag(id)

        default:
            break
        }
    }

    private func endDrag(_ id: String) {
        guard let session = activeDrag, session.windowId == id else { return }

        // Remove monitors
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }

        let finalFrame = session.panel.frame
        activeDrag = nil

        os_log("dragEnded id=%{public}@ frame=%{public}@",
               log: Log.frame, type: .debug, id, NSStringFromRect(finalFrame))
        delegate?.dragEnded(id, frame: finalFrame)
    }

    /// Check if a window is currently being dragged
    func isDragging(_ id: String) -> Bool {
        activeDrag?.windowId == id
    }
}
