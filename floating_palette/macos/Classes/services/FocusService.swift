import Cocoa
import FlutterMacOS

/// Handles window focus and activation.
final class FocusService {
    private let store = WindowStore.shared
    private var eventSink: ((String, String, String?, [String: Any]) -> Void)?

    func setEventSink(_ sink: @escaping (String, String, String?, [String: Any]) -> Void) {
        self.eventSink = sink
    }

    // MARK: - Commands

    func handle(_ command: String, windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        switch command {
        case "focus":
            focus(windowId: windowId, result: result)
        case "unfocus":
            unfocus(windowId: windowId, result: result)
        case "setPolicy":
            setPolicy(windowId: windowId, params: params, result: result)
        case "isFocused":
            isFocused(windowId: windowId, result: result)
        case "focusMainWindow":
            focusMainWindow(result: result)
        case "hideApp":
            hideApp(result: result)
        default:
            result(FlutterError(code: "UNKNOWN_COMMAND", message: "Unknown focus command: \(command)", details: nil))
        }
    }

    // MARK: - Focus

    private func focus(windowId: String?, result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        DispatchQueue.main.async { [weak self] in
            let panel = window.panel

            // Remove nonactivatingPanel to allow keyboard focus
            panel.styleMask.remove(.nonactivatingPanel)

            // Make key and bring to front
            panel.makeKeyAndOrderFront(nil)

            // Activate the app so panel can become key
            NSApp.activate(ignoringOtherApps: true)

            // Make the Flutter content view first responder for keyboard input
            if let contentView = panel.contentView {
                panel.makeFirstResponder(contentView)
            }

            self?.eventSink?("focus", "focused", id, [:])
            result(nil)
        }
    }

    private func unfocus(windowId: String?, result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        DispatchQueue.main.async { [weak self] in
            let panel = window.panel

            // Resign key window status
            panel.resignKey()

            // Restore nonactivatingPanel style for floating behavior
            panel.styleMask.insert(.nonactivatingPanel)

            self?.eventSink?("focus", "unfocused", id, [:])
            result(nil)
        }
    }

    // MARK: - Policy

    private func setPolicy(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        guard let policy = params["policy"] as? String else {
            result(FlutterError(code: "INVALID_PARAMS", message: "policy required", details: nil))
            return
        }

        DispatchQueue.main.async {
            let panel = window.panel

            switch policy {
            case "never":
                // Panel never takes focus
                panel.styleMask.insert(.nonactivatingPanel)
                panel.becomesKeyOnlyIfNeeded = true

            case "always":
                // Panel always takes focus when shown
                panel.styleMask.remove(.nonactivatingPanel)
                panel.becomesKeyOnlyIfNeeded = false

            case "onClick":
                // Panel takes focus only on click
                panel.styleMask.insert(.nonactivatingPanel)
                panel.becomesKeyOnlyIfNeeded = true
                panel.acceptsMouseMovedEvents = true

            default:
                break
            }

            result(nil)
        }
    }

    private func isFocused(windowId: String?, result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(false)
            return
        }

        result(window.panel.isKeyWindow)
    }

    // MARK: - App Focus

    /// Activate the main app window.
    private func focusMainWindow(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            if let mainWindow = NSApp.mainWindow {
                mainWindow.makeKeyAndOrderFront(nil)
            }
            result(nil)
        }
    }

    /// Hide the app entirely (returns to previously active app).
    private func hideApp(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            NSApp.hide(nil)
            result(nil)
        }
    }
}
