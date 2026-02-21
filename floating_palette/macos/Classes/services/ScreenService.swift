import Cocoa
import FlutterMacOS

/// Handles screen information and positioning.
final class ScreenService {
    private let store = WindowStore.shared
    private var eventSink: ((String, String, String?, [String: Any]) -> Void)?

    func setEventSink(_ sink: @escaping (String, String, String?, [String: Any]) -> Void) {
        self.eventSink = sink
    }

    // MARK: - Commands

    func handle(_ command: String, windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        switch command {
        case "getScreens":
            getScreens(result: result)
        case "getCurrentScreen":
            getCurrentScreen(windowId: windowId, result: result)
        case "getWindowScreen":
            getWindowScreen(windowId: windowId, result: result)
        case "moveToScreen":
            moveToScreen(windowId: windowId, params: params, result: result)
        case "getCursorPosition":
            getCursorPosition(result: result)
        case "getCursorScreen":
            getCursorScreen(result: result)
        case "getActiveAppBounds":
            getActiveAppBounds(result: result)
        default:
            result(FlutterError(code: "UNKNOWN_COMMAND", message: "Unknown screen command: \(command)", details: nil))
        }
    }

    // MARK: - Screens

    private func getScreens(result: @escaping FlutterResult) {
        let screens = NSScreen.screens.enumerated().map { index, screen -> [String: Any] in
            let frame = screen.frame
            let visibleFrame = screen.visibleFrame
            return [
                "id": index,
                "name": screen.localizedName,
                "isPrimary": screen == NSScreen.main,
                "frame": [
                    "x": frame.origin.x,
                    "y": frame.origin.y,
                    "width": frame.width,
                    "height": frame.height
                ],
                "visibleFrame": [
                    "x": visibleFrame.origin.x,
                    "y": visibleFrame.origin.y,
                    "width": visibleFrame.width,
                    "height": visibleFrame.height
                ],
                "scaleFactor": screen.backingScaleFactor
            ]
        }
        result(screens)
    }

    private func getCurrentScreen(windowId: String?, result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        guard let screen = window.panel.screen else {
            result(nil)
            return
        }

        let frame = screen.frame
        let visibleFrame = screen.visibleFrame
        let index = NSScreen.screens.firstIndex(of: screen) ?? 0

        result([
            "id": index,
            "name": screen.localizedName,
            "isPrimary": screen == NSScreen.main,
            "frame": [
                "x": frame.origin.x,
                "y": frame.origin.y,
                "width": frame.width,
                "height": frame.height
            ],
            "visibleFrame": [
                "x": visibleFrame.origin.x,
                "y": visibleFrame.origin.y,
                "width": visibleFrame.width,
                "height": visibleFrame.height
            ],
            "scaleFactor": screen.backingScaleFactor
        ])
    }

    private func getWindowScreen(windowId: String?, result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        guard let screen = window.panel.screen else {
            result(0)
            return
        }

        let index = NSScreen.screens.firstIndex(of: screen) ?? 0
        result(index)
    }

    // MARK: - Move to Screen

    private func moveToScreen(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        // Accept both 'screenId' and 'screenIndex' for compatibility
        guard let screenId = params["screenId"] as? Int ?? params["screenIndex"] as? Int,
              screenId < NSScreen.screens.count else {
            result(FlutterError(code: "INVALID_SCREEN", message: "Invalid screen ID", details: nil))
            return
        }

        let targetScreen = NSScreen.screens[screenId]
        let anchor = params["anchor"] as? String ?? "center"
        let animate = params["animate"] as? Bool ?? false
        let durationMs = params["durationMs"] as? Int ?? 200

        DispatchQueue.main.async { [weak self] in
            let panel = window.panel
            let windowSize = panel.frame.size
            let screenFrame = targetScreen.visibleFrame

            let newOrigin = self?.calculatePosition(
                anchor: anchor,
                windowSize: windowSize,
                screenFrame: screenFrame
            ) ?? screenFrame.origin

            let newFrame = NSRect(origin: newOrigin, size: windowSize)

            if animate {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = Double(durationMs) / 1000.0
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    panel.animator().setFrame(newFrame, display: true)
                } completionHandler: {
                    self?.eventSink?("screen", "movedToScreen", id, ["screenId": screenId])
                }
            } else {
                panel.setFrame(newFrame, display: true)
                self?.eventSink?("screen", "movedToScreen", id, ["screenId": screenId])
            }

            result(nil)
        }
    }

    private func calculatePosition(anchor: String, windowSize: NSSize, screenFrame: NSRect) -> NSPoint {
        switch anchor {
        case "topLeft":
            return NSPoint(x: screenFrame.minX, y: screenFrame.maxY - windowSize.height)
        case "topCenter":
            return NSPoint(x: screenFrame.midX - windowSize.width / 2, y: screenFrame.maxY - windowSize.height)
        case "topRight":
            return NSPoint(x: screenFrame.maxX - windowSize.width, y: screenFrame.maxY - windowSize.height)
        case "centerLeft":
            return NSPoint(x: screenFrame.minX, y: screenFrame.midY - windowSize.height / 2)
        case "center":
            return NSPoint(x: screenFrame.midX - windowSize.width / 2, y: screenFrame.midY - windowSize.height / 2)
        case "centerRight":
            return NSPoint(x: screenFrame.maxX - windowSize.width, y: screenFrame.midY - windowSize.height / 2)
        case "bottomLeft":
            return NSPoint(x: screenFrame.minX, y: screenFrame.minY)
        case "bottomCenter":
            return NSPoint(x: screenFrame.midX - windowSize.width / 2, y: screenFrame.minY)
        case "bottomRight":
            return NSPoint(x: screenFrame.maxX - windowSize.width, y: screenFrame.minY)
        default:
            return NSPoint(x: screenFrame.midX - windowSize.width / 2, y: screenFrame.midY - windowSize.height / 2)
        }
    }

    // MARK: - Cursor

    private func getCursorPosition(result: @escaping FlutterResult) {
        let mouseLocation = NSEvent.mouseLocation
        result([
            "x": mouseLocation.x,
            "y": mouseLocation.y
        ])
    }

    private func getCursorScreen(result: @escaping FlutterResult) {
        let mouseLocation = NSEvent.mouseLocation

        // Find which screen contains the cursor
        for (index, screen) in NSScreen.screens.enumerated() {
            if screen.frame.contains(mouseLocation) {
                result(index)
                return
            }
        }

        // Default to primary screen if cursor position not found (shouldn't happen)
        result(0)
    }

    // MARK: - Active App

    private func getActiveAppBounds(result: @escaping FlutterResult) {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let pid = frontApp.processIdentifier as pid_t? else {
            result(nil)
            return
        }

        // Get windows for the frontmost application
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            result(nil)
            return
        }

        // Find the frontmost window of the active app
        for windowInfo in windowList {
            guard let windowPID = windowInfo[kCGWindowOwnerPID as String] as? Int32,
                  windowPID == pid,
                  let bounds = windowInfo[kCGWindowBounds as String] as? [String: CGFloat] else {
                continue
            }

            let x = bounds["X"] ?? 0
            let y = bounds["Y"] ?? 0
            let width = bounds["Width"] ?? 0
            let height = bounds["Height"] ?? 0
            result([
                "x": x,
                "y": y,
                "width": width,
                "height": height,
                "appName": frontApp.localizedName ?? ""
            ] as [String: Any])
            return
        }

        result(nil)
    }
}
