import Cocoa
import FlutterMacOS
import os.log

/// Handles window visibility: show, hide, opacity.
final class VisibilityService {
    /// Shared instance for FFI access to eventSink
    static var shared: VisibilityService?

    private let store = WindowStore.shared
    private var eventSink: ((String, String, String?, [String: Any]) -> Void)?

    /// Reference to snap service for snap notifications
    private weak var snapService: SnapService?

    /// Safety timer work items per window (to cancel if reveal happens first)
    private var revealTimers: [String: DispatchWorkItem] = [:]

    /// Safety timer delay in milliseconds
    private static let revealSafetyMs: Double = 100

    init() {
        VisibilityService.shared = self
    }

    /// Set reference to snap service for snap notifications.
    func setSnapService(_ service: SnapService?) {
        self.snapService = service
    }

    func setEventSink(_ sink: @escaping (String, String, String?, [String: Any]) -> Void) {
        self.eventSink = sink
    }

    // MARK: - Commands

    func handle(_ command: String, windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        switch command {
        case "show":
            show(windowId: windowId, params: params, result: result)
        case "hide":
            hide(windowId: windowId, params: params, result: result)
        case "setOpacity":
            setOpacity(windowId: windowId, params: params, result: result)
        case "getOpacity":
            getOpacity(windowId: windowId, result: result)
        case "isVisible":
            isVisible(windowId: windowId, result: result)
        default:
            result(FlutterError(code: "UNKNOWN_COMMAND", message: "Unknown visibility command: \(command)", details: nil))
        }
    }

    // MARK: - Show (with show-after-sized pattern)

    private func show(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            os_log("show failed: window not found", log: Log.visibility, type: .error)
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        os_log("show id=%{public}@", log: Log.visibility, type: .debug, id)
        let animate = params["animate"] as? Bool ?? false
        let durationMs = params["durationMs"] as? Int ?? 200
        let focus = params["focus"] as? Bool ?? true

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let panel = window.panel

            // Store focus preference for reveal
            window.shouldFocus = focus

            // Configure panel to never take focus if focus=false (TakesFocus.no)
            if let keyablePanel = panel as? KeyablePanel {
                keyablePanel.neverTakesFocus = !focus
            }

            // Set pending reveal - FFI will trigger actual reveal after first resize
            window.isPendingReveal = true

            // Tell palette Flutter engine to force a size report
            window.entryChannel?.invokeMethod("forceResize", arguments: nil)

            // Remember key window before showing (for non-focused panels)
            let previousKeyWindow = focus ? nil : NSApp.keyWindow

            // Show panel immediately (but Flutter hasn't rendered correct size yet)
            if animate {
                panel.alphaValue = 0
                panel.orderFront(nil)

                NSAnimationContext.runAnimationGroup { context in
                    context.duration = Double(durationMs) / 1000.0
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    panel.animator().alphaValue = 1
                }
            } else {
                panel.orderFront(nil)
            }

            // Restore focus if this panel shouldn't take it
            if !focus, let prev = previousKeyWindow, !prev.isKeyWindow {
                prev.makeKey()
            }

            // Start safety timer - reveal after delay if FFI resize hasn't happened
            self.startRevealTimer(windowId: id)

            result(nil)
        }
    }

    // MARK: - Reveal (called by FFI or safety timer)

    /// Reveal a window after Flutter has rendered content.
    /// Called by FFI after first resize or by safety timer.
    func reveal(windowId: String) {
        guard let window = store.get(windowId) else { return }

        os_log("reveal id=%{public}@", log: Log.visibility, type: .info, windowId)

        // Cancel safety timer
        revealTimers[windowId]?.cancel()
        revealTimers.removeValue(forKey: windowId)

        // Delegate to window's reveal method
        window.reveal(eventSink: eventSink)

        // Notify snap service of window being shown
        snapService?.onWindowShown(id: windowId)
    }

    private func startRevealTimer(windowId: String) {
        // Cancel existing timer if any
        revealTimers[windowId]?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.reveal(windowId: windowId)
        }
        revealTimers[windowId] = workItem

        DispatchQueue.main.asyncAfter(
            deadline: .now() + VisibilityService.revealSafetyMs / 1000.0,
            execute: workItem
        )
    }

    // MARK: - Hide

    private func hide(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            os_log("hide failed: window not found", log: Log.visibility, type: .error)
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        os_log("hide id=%{public}@", log: Log.visibility, type: .info, id)
        let animate = params["animate"] as? Bool ?? false
        let durationMs = params["durationMs"] as? Int ?? 200

        // Cancel any pending reveal timer
        revealTimers[id]?.cancel()
        revealTimers.removeValue(forKey: id)

        DispatchQueue.main.async { [weak self] in
            let panel = window.panel

            // Reset pending reveal state
            window.isPendingReveal = false

            // Re-add nonactivatingPanel for next show cycle
            panel.styleMask.insert(.nonactivatingPanel)

            if animate {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = Double(durationMs) / 1000.0
                    context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                    panel.animator().alphaValue = 0
                } completionHandler: {
                    panel.orderOut(nil)
                    panel.alphaValue = 1  // Reset for next show
                    self?.eventSink?("visibility", "hidden", id, [:])
                    // Notify snap service of window being hidden
                    self?.snapService?.onWindowHidden(id: id)
                }
            } else {
                panel.orderOut(nil)
                self?.eventSink?("visibility", "hidden", id, [:])
                // Notify snap service of window being hidden
                self?.snapService?.onWindowHidden(id: id)
            }

            result(nil)
        }
    }

    // MARK: - Opacity

    private func setOpacity(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        guard let opacity = params["opacity"] as? Double else {
            result(FlutterError(code: "INVALID_PARAMS", message: "opacity required", details: nil))
            return
        }

        let animate = params["animate"] as? Bool ?? false
        let durationMs = params["durationMs"] as? Int ?? 200

        DispatchQueue.main.async { [weak self] in
            let panel = window.panel
            let clampedOpacity = max(0, min(1, opacity))

            if animate {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = Double(durationMs) / 1000.0
                    panel.animator().alphaValue = clampedOpacity
                } completionHandler: {
                    self?.eventSink?("visibility", "opacityChanged", id, ["opacity": clampedOpacity])
                }
            } else {
                panel.alphaValue = clampedOpacity
                self?.eventSink?("visibility", "opacityChanged", id, ["opacity": clampedOpacity])
            }

            result(nil)
        }
    }

    private func getOpacity(windowId: String?, result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        result(window.panel.alphaValue)
    }

    private func isVisible(windowId: String?, result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(false)
            return
        }

        result(window.panel.isVisible)
    }
}
