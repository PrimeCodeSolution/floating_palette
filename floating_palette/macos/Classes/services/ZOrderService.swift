import Cocoa
import FlutterMacOS

/// Handles window z-order and level.
final class ZOrderService {
    private let store = WindowStore.shared
    private var eventSink: ((String, String, String?, [String: Any]) -> Void)?
    private var pinnedWindows: Set<String> = []

    // Track logical z-index for each window (for Dart-side ordering)
    private var zIndexState: [String: Int] = [:]

    func setEventSink(_ sink: @escaping (String, String, String?, [String: Any]) -> Void) {
        self.eventSink = sink
    }

    // MARK: - Commands

    func handle(_ command: String, windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        switch command {
        case "bringToFront":
            bringToFront(windowId: windowId, result: result)
        case "sendToBack":
            sendToBack(windowId: windowId, result: result)
        case "moveAbove":
            moveAbove(windowId: windowId, params: params, result: result)
        case "moveBelow":
            moveBelow(windowId: windowId, params: params, result: result)
        case "setZIndex":
            setZIndex(windowId: windowId, params: params, result: result)
        case "getZIndex":
            getZIndex(windowId: windowId, result: result)
        case "setLevel":
            setLevel(windowId: windowId, params: params, result: result)
        case "pin":
            pin(windowId: windowId, params: params, result: result)
        case "unpin":
            unpin(windowId: windowId, result: result)
        case "isPinned":
            isPinned(windowId: windowId, result: result)
        default:
            result(FlutterError(code: "UNKNOWN_COMMAND", message: "Unknown zorder command: \(command)", details: nil))
        }
    }

    // MARK: - Z-Order

    private func bringToFront(windowId: String?, result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        DispatchQueue.main.async { [weak self] in
            window.panel.orderFront(nil)
            self?.eventSink?("zorder", "changed", id, ["position": "front"])
            result(nil)
        }
    }

    private func sendToBack(windowId: String?, result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        DispatchQueue.main.async { [weak self] in
            window.panel.orderBack(nil)
            self?.eventSink?("zorder", "changed", id, ["position": "back"])
            result(nil)
        }
    }

    // MARK: - Relative Ordering

    private func moveAbove(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        guard let otherId = params["otherId"] as? String,
              let otherWindow = store.get(otherId) else {
            result(FlutterError(code: "NOT_FOUND", message: "Other window not found", details: nil))
            return
        }

        DispatchQueue.main.async { [weak self] in
            window.panel.order(.above, relativeTo: otherWindow.panel.windowNumber)
            self?.eventSink?("zorder", "changed", id, ["position": "above", "otherId": otherId])
            result(nil)
        }
    }

    private func moveBelow(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        guard let otherId = params["otherId"] as? String,
              let otherWindow = store.get(otherId) else {
            result(FlutterError(code: "NOT_FOUND", message: "Other window not found", details: nil))
            return
        }

        DispatchQueue.main.async { [weak self] in
            window.panel.order(.below, relativeTo: otherWindow.panel.windowNumber)
            self?.eventSink?("zorder", "changed", id, ["position": "below", "otherId": otherId])
            result(nil)
        }
    }

    // MARK: - Z-Index

    private func setZIndex(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, store.get(id) != nil else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        guard let index = params["index"] as? Int else {
            result(FlutterError(code: "INVALID_PARAMS", message: "index required", details: nil))
            return
        }

        // Store logical z-index
        zIndexState[id] = index

        // Apply ordering based on z-index relative to other windows
        DispatchQueue.main.async { [weak self] in
            // Sort all windows by their z-index and re-order them
            self?.reorderWindowsByZIndex()
            self?.eventSink?("zorder", "zOrderChanged", id, ["index": index])
            result(nil)
        }
    }

    private func getZIndex(windowId: String?, result: @escaping FlutterResult) {
        guard let id = windowId else {
            result(0)
            return
        }
        result(zIndexState[id] ?? 0)
    }

    private func reorderWindowsByZIndex() {
        // Get all windows with z-index, sorted by index
        let sortedEntries = zIndexState.sorted { $0.value < $1.value }

        // Apply ordering (lower z-index = further back)
        for (index, entry) in sortedEntries.enumerated() {
            if let window = store.get(entry.key) {
                if index == 0 {
                    window.panel.orderBack(nil)
                } else {
                    // Get the previous window and order above it
                    let previousId = sortedEntries[index - 1].key
                    if let previousWindow = store.get(previousId) {
                        window.panel.order(.above, relativeTo: previousWindow.panel.windowNumber)
                    }
                }
            }
        }
    }

    // MARK: - Level

    private func setLevel(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        guard let levelName = params["level"] as? String else {
            result(FlutterError(code: "INVALID_PARAMS", message: "level required", details: nil))
            return
        }

        let level = windowLevel(for: levelName)

        DispatchQueue.main.async { [weak self] in
            window.panel.level = level
            self?.eventSink?("zorder", "levelChanged", id, ["level": levelName])
            result(nil)
        }
    }

    private func windowLevel(for name: String) -> NSWindow.Level {
        switch name {
        case "normal": return .normal
        case "floating": return .floating
        case "modalPanel": return .modalPanel
        case "mainMenu": return .mainMenu
        case "statusBar": return .statusBar
        case "popUpMenu": return .popUpMenu
        case "screenSaver": return .screenSaver
        default: return .floating
        }
    }

    // MARK: - Pin

    private func pin(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        // Support both old API (aboveAll: Bool) and new API (level: String)
        let level: NSWindow.Level
        let levelName: String

        if let levelString = params["level"] as? String {
            // New API: level string from PinLevel enum
            switch levelString {
            case "abovePalettes":
                level = .floating
                levelName = levelString
            case "aboveApp":
                level = .modalPanel
                levelName = levelString
            case "aboveAll":
                level = .screenSaver
                levelName = levelString
            default:
                level = .floating
                levelName = "abovePalettes"
            }
        } else {
            // Legacy API: aboveAll boolean
            let aboveAll = params["aboveAll"] as? Bool ?? true
            level = aboveAll ? .screenSaver : .floating
            levelName = aboveAll ? "aboveAll" : "abovePalettes"
        }

        DispatchQueue.main.async { [weak self] in
            window.panel.level = level
            // .canJoinAllSpaces and .moveToActiveSpace are mutually exclusive
            window.panel.collectionBehavior.remove(.moveToActiveSpace)
            window.panel.collectionBehavior.insert(.canJoinAllSpaces)
            self?.pinnedWindows.insert(id)
            self?.eventSink?("zorder", "pinned", id, ["level": levelName])
            result(nil)
        }
    }

    private func unpin(windowId: String?, result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        DispatchQueue.main.async { [weak self] in
            window.panel.level = .floating
            // Restore default behavior
            window.panel.collectionBehavior.remove(.canJoinAllSpaces)
            window.panel.collectionBehavior.insert(.moveToActiveSpace)
            self?.pinnedWindows.remove(id)
            self?.eventSink?("zorder", "unpinned", id, [:])
            result(nil)
        }
    }

    private func isPinned(windowId: String?, result: @escaping FlutterResult) {
        guard let id = windowId else {
            result(false)
            return
        }
        result(pinnedWindows.contains(id))
    }
}
