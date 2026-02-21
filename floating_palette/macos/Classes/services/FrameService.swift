import Cocoa
import FlutterMacOS
import os.log

/// Handles window position and size.
final class FrameService {
    private let store = WindowStore.shared
    private var eventSink: ((String, String, String?, [String: Any]) -> Void)?

    /// Tracks observer tokens for each window to allow cleanup
    private var moveObservers: [String: NSObjectProtocol] = [:]
    private var resizeObservers: [String: NSObjectProtocol] = [:]

    /// Reference to snap service for snap notifications
    private weak var snapService: SnapService?

    /// Reference to drag coordinator for drag lifecycle management
    private weak var dragCoordinator: DragCoordinator?

    /// Set reference to snap service for snap notifications.
    func setSnapService(_ service: SnapService?) {
        self.snapService = service
    }

    /// Set reference to drag coordinator for drag lifecycle management.
    func setDragCoordinator(_ coordinator: DragCoordinator?) {
        self.dragCoordinator = coordinator
    }

    func setEventSink(_ sink: @escaping (String, String, String?, [String: Any]) -> Void) {
        self.eventSink = sink
    }

    // MARK: - Window Frame Observers

    /// Observe user-initiated frame changes for a window.
    ///
    /// Sets up observers for NSWindow.didMoveNotification and NSWindow.didResizeNotification
    /// to detect when the user drags or resizes the window. Events include full bounds
    /// and `source: "user"` to distinguish from programmatic changes.
    func observeWindowFrame(_ window: PaletteWindow) {
        let id = window.id
        let panel = window.panel

        // Remove any existing observers
        removeObservers(for: id)

        // Observe moves (non-drag moves only - drags are handled by DragCoordinator)
        let moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            // Skip if this window is being dragged - DragCoordinator handles those
            if self?.dragCoordinator?.isDragging(id) == true { return }

            let frame = panel.frame
            os_log("didMove id=%{public}@ frame=%{public}@", log: Log.frame, type: .debug, id, NSStringFromRect(frame))
            self?.eventSink?("frame", "moved", id, [
                "x": frame.origin.x,
                "y": frame.origin.y,
                "width": frame.size.width,
                "height": frame.size.height,
                "source": "user"
            ])
            // Non-drag moves (programmatic, snap repositioning)
            self?.snapService?.onWindowMoved(id: id, frame: frame, isUserDrag: false)
        }
        moveObservers[id] = moveObserver

        // Observe user-initiated resizes
        let resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            let frame = panel.frame
            self?.eventSink?("frame", "resized", id, [
                "x": frame.origin.x,
                "y": frame.origin.y,
                "width": frame.size.width,
                "height": frame.size.height,
                "source": "user"
            ])
            // Notify snap service of resize
            self?.snapService?.onWindowResized(id: id, frame: frame)
        }
        resizeObservers[id] = resizeObserver
    }

    /// Remove observers for a window (called when window is destroyed).
    func removeObservers(for id: String) {
        if let observer = moveObservers.removeValue(forKey: id) {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = resizeObservers.removeValue(forKey: id) {
            NotificationCenter.default.removeObserver(observer)
        }
        // Note: drag state cleanup is handled by DragCoordinator
    }

    // MARK: - Commands

    func handle(_ command: String, windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        switch command {
        case "setPosition":
            setPosition(windowId: windowId, params: params, result: result)
        case "setSize":
            setSize(windowId: windowId, params: params, result: result)
        case "setBounds":
            setBounds(windowId: windowId, params: params, result: result)
        case "getPosition":
            getPosition(windowId: windowId, result: result)
        case "getSize":
            getSize(windowId: windowId, result: result)
        case "getBounds":
            getBounds(windowId: windowId, result: result)
        case "startDrag":
            startDrag(windowId: windowId, result: result)
        case "setDraggable":
            setDraggable(windowId: windowId, params: params, result: result)
        default:
            result(FlutterError(code: "UNKNOWN_COMMAND", message: "Unknown frame command: \(command)", details: nil))
        }
    }

    // MARK: - Set Position

    private func setPosition(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        guard let x = params["x"] as? Double,
              let y = params["y"] as? Double else {
            result(FlutterError(code: "INVALID_PARAMS", message: "x and y required", details: nil))
            return
        }

        let anchor = params["anchor"] as? String ?? "topLeft"
        let animate = params["animate"] as? Bool ?? false
        let durationMs = params["durationMs"] as? Int ?? 200

        DispatchQueue.main.async { [weak self] in
            let panel = window.panel
            let size = panel.frame.size

            // Calculate origin based on anchor
            // The anchor specifies which point of the window should be at (x, y)
            let origin = self?.calculateOrigin(
                targetX: x,
                targetY: y,
                windowSize: size,
                anchor: anchor
            ) ?? NSPoint(x: x, y: y)

            let newFrame = NSRect(origin: origin, size: size)

            if animate {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = Double(durationMs) / 1000.0
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    panel.animator().setFrame(newFrame, display: true)
                } completionHandler: {
                    self?.eventSink?("frame", "moved", id, [
                        "x": origin.x,
                        "y": origin.y,
                        "width": size.width,
                        "height": size.height,
                        "source": "programmatic"
                    ])
                    // Notify snap service of programmatic move
                    self?.snapService?.onWindowMoved(id: id, frame: newFrame, isUserDrag: false)
                }
            } else {
                panel.setFrameOrigin(origin)
                self?.eventSink?("frame", "moved", id, [
                    "x": origin.x,
                    "y": origin.y,
                    "width": size.width,
                    "height": size.height,
                    "source": "programmatic"
                ])
                // Notify snap service of programmatic move
                self?.snapService?.onWindowMoved(id: id, frame: newFrame, isUserDrag: false)
            }

            result(nil)
        }
    }

    /// Calculate window origin based on anchor point.
    /// Anchor specifies which point of the window should be at the target position.
    private func calculateOrigin(targetX: Double, targetY: Double, windowSize: NSSize, anchor: String) -> NSPoint {
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0

        // Horizontal offset
        if anchor.contains("Left") {
            offsetX = 0
        } else if anchor.contains("Right") {
            offsetX = -windowSize.width
        } else if anchor.contains("center") || anchor.contains("Center") {
            offsetX = -windowSize.width / 2
        }

        // Vertical offset (macOS Y is bottom-up)
        if anchor.hasPrefix("top") {
            offsetY = -windowSize.height
        } else if anchor.hasPrefix("bottom") {
            offsetY = 0
        } else if anchor.hasPrefix("center") {
            offsetY = -windowSize.height / 2
        }

        return NSPoint(x: targetX + offsetX, y: targetY + offsetY)
    }

    // MARK: - Set Size

    private func setSize(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        guard let width = params["width"] as? Double,
              let height = params["height"] as? Double else {
            result(FlutterError(code: "INVALID_PARAMS", message: "width and height required", details: nil))
            return
        }

        let animate = params["animate"] as? Bool ?? false
        let durationMs = params["durationMs"] as? Int ?? 200

        DispatchQueue.main.async { [weak self] in
            let panel = window.panel
            let currentFrame = panel.frame
            let newSize = NSSize(width: width, height: height)
            let newFrame = NSRect(origin: currentFrame.origin, size: newSize)

            if animate {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = Double(durationMs) / 1000.0
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    panel.animator().setFrame(newFrame, display: true)
                } completionHandler: {
                    let frame = panel.frame
                    self?.eventSink?("frame", "resized", id, [
                        "x": frame.origin.x,
                        "y": frame.origin.y,
                        "width": width,
                        "height": height,
                        "source": "programmatic"
                    ])
                    // Notify snap service of resize
                    self?.snapService?.onWindowResized(id: id, frame: frame)
                }
            } else {
                panel.setContentSize(newSize)
                let frame = panel.frame
                self?.eventSink?("frame", "resized", id, [
                    "x": frame.origin.x,
                    "y": frame.origin.y,
                    "width": width,
                    "height": height,
                    "source": "programmatic"
                ])
                // Notify snap service of resize
                self?.snapService?.onWindowResized(id: id, frame: frame)
            }

            result(nil)
        }
    }

    // MARK: - Set Bounds

    private func setBounds(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        guard let x = params["x"] as? Double,
              let y = params["y"] as? Double,
              let width = params["width"] as? Double,
              let height = params["height"] as? Double else {
            result(FlutterError(code: "INVALID_PARAMS", message: "x, y, width, height required", details: nil))
            return
        }

        let animate = params["animate"] as? Bool ?? false
        let durationMs = params["durationMs"] as? Int ?? 200

        DispatchQueue.main.async { [weak self] in
            let panel = window.panel
            let newFrame = NSRect(x: x, y: y, width: width, height: height)

            if animate {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = Double(durationMs) / 1000.0
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    panel.animator().setFrame(newFrame, display: true)
                } completionHandler: {
                    self?.eventSink?("frame", "moved", id, [
                        "x": x,
                        "y": y,
                        "width": width,
                        "height": height,
                        "source": "programmatic"
                    ])
                    // Notify snap service of programmatic move/resize
                    self?.snapService?.onWindowMoved(id: id, frame: newFrame, isUserDrag: false)
                    self?.snapService?.onWindowResized(id: id, frame: newFrame)
                }
            } else {
                panel.setFrame(newFrame, display: true)
                self?.eventSink?("frame", "moved", id, [
                    "x": x,
                    "y": y,
                    "width": width,
                    "height": height,
                    "source": "programmatic"
                ])
                // Notify snap service of programmatic move/resize
                self?.snapService?.onWindowMoved(id: id, frame: newFrame, isUserDrag: false)
                self?.snapService?.onWindowResized(id: id, frame: newFrame)
            }

            result(nil)
        }
    }

    // MARK: - Getters

    private func getPosition(windowId: String?, result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        let frame = window.panel.frame
        result(["x": frame.origin.x, "y": frame.origin.y])
    }

    private func getSize(windowId: String?, result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        let frame = window.panel.frame
        result(["width": frame.width, "height": frame.height])
    }

    private func getBounds(windowId: String?, result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        let frame = window.panel.frame
        result([
            "x": frame.origin.x,
            "y": frame.origin.y,
            "width": frame.width,
            "height": frame.height
        ])
    }

    // MARK: - Drag

    private func setDraggable(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }
        guard let draggable = params["draggable"] as? Bool else {
            result(FlutterError(code: "INVALID_ARGS", message: "draggable (bool) required", details: nil))
            return
        }
        window.draggable = draggable
        result(nil)
    }

    private func startDrag(windowId: String?, result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        DispatchQueue.main.async { [weak self] in
            os_log("startDrag command id=%{public}@", log: Log.frame, type: .debug, id)
            self?.dragCoordinator?.startDrag(id, window: window)
            result(nil)
        }
    }
}
