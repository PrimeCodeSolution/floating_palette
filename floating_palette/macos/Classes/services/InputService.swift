import Cocoa
import FlutterMacOS
import os.log

/// Handles keyboard, pointer, and cursor.
final class InputService {
    private let store = WindowStore.shared
    private var eventSink: ((String, String, String?, [String: Any]) -> Void)?
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?
    private var globalMouseMonitor: Any?
    private var capturedWindows: Set<String> = []

    /// Keys to capture per window: windowId -> Set of Flutter logical key IDs
    private var capturedKeys: [String: Set<Int>] = [:]

    /// Whether to capture all keys for a window
    private var captureAllKeys: [String: Bool] = [:]

    /// Tracks keyCodes whose keyDown events were passed through (not consumed) by the local monitor.
    /// When keyUp arrives, if the keyCode is in this set, we MUST pass it through too —
    /// regardless of current capture state — to keep HardwareKeyboard's pressed-key tracking consistent.
    private var passedThroughKeyCodes: Set<UInt16> = []

    // MARK: - macOS keyCode to Flutter LogicalKeyboardKey.keyId mapping
    // Flutter key IDs from: https://api.flutter.dev/flutter/services/LogicalKeyboardKey-class.html
    private static let keyCodeToFlutterKeyId: [UInt16: Int] = [
        // Arrow keys
        126: 0x100000304, // arrowUp
        125: 0x100000301, // arrowDown
        123: 0x100000302, // arrowLeft
        124: 0x100000303, // arrowRight
        // Control keys
        36: 0x10000000d,  // enter
        76: 0x10000000d,  // numpad enter
        53: 0x10000001b,  // escape
        48: 0x100000009,  // tab
        51: 0x100000008,  // backspace
        117: 0x10000007f, // delete (forward delete)
        // Navigation
        115: 0x100000306, // home
        119: 0x100000305, // end
        116: 0x100000308, // pageUp
        121: 0x100000307, // pageDown
        // Letters (a-z)
        0: 0x00000061,   // a
        11: 0x00000062,  // b
        8: 0x00000063,   // c
        2: 0x00000064,   // d
        14: 0x00000065,  // e
        3: 0x00000066,   // f
        5: 0x00000067,   // g
        4: 0x00000068,   // h
        34: 0x00000069,  // i
        38: 0x0000006a,  // j
        40: 0x0000006b,  // k
        37: 0x0000006c,  // l
        46: 0x0000006d,  // m
        45: 0x0000006e,  // n
        31: 0x0000006f,  // o
        35: 0x00000070,  // p
        12: 0x00000071,  // q
        15: 0x00000072,  // r
        1: 0x00000073,   // s
        17: 0x00000074,  // t
        32: 0x00000075,  // u
        9: 0x00000076,   // v
        13: 0x00000077,  // w
        7: 0x00000078,   // x
        16: 0x00000079,  // y
        6: 0x0000007a,   // z
        // Numbers (0-9)
        29: 0x00000030,  // 0
        18: 0x00000031,  // 1
        19: 0x00000032,  // 2
        20: 0x00000033,  // 3
        21: 0x00000034,  // 4
        23: 0x00000035,  // 5
        22: 0x00000036,  // 6
        26: 0x00000037,  // 7
        28: 0x00000038,  // 8
        25: 0x00000039,  // 9
        // Space
        49: 0x00000020,  // space
        // Function keys
        122: 0x100000801, // F1
        120: 0x100000802, // F2
        99:  0x100000803, // F3
        118: 0x100000804, // F4
        96:  0x100000805, // F5
        97:  0x100000806, // F6
        98:  0x100000807, // F7
        100: 0x100000808, // F8
        101: 0x100000809, // F9
        109: 0x10000080a, // F10
        103: 0x10000080b, // F11
        111: 0x10000080c, // F12
    ]

    func setEventSink(_ sink: @escaping (String, String, String?, [String: Any]) -> Void) {
        self.eventSink = sink
    }

    // MARK: - Commands

    func handle(_ command: String, windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        switch command {
        case "captureKeyboard":
            captureKeyboard(windowId: windowId, params: params, result: result)
        case "releaseKeyboard":
            releaseKeyboard(windowId: windowId, result: result)
        case "capturePointer":
            capturePointer(windowId: windowId, result: result)
        case "releasePointer":
            releasePointer(windowId: windowId, result: result)
        case "setCursor":
            setCursor(windowId: windowId, params: params, result: result)
        case "resetCursor":
            resetCursor(windowId: windowId, result: result)
        case "setPassthrough":
            setPassthrough(windowId: windowId, params: params, result: result)
        default:
            result(FlutterError(code: "UNKNOWN_COMMAND", message: "Unknown input command: \(command)", details: nil))
        }
    }

    // MARK: - Keyboard Capture

    private func captureKeyboard(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, store.exists(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        let allKeys = params["allKeys"] as? Bool ?? false

        // Flutter key IDs can exceed Int32, so we need to handle them as Int64/NSNumber
        // IMPORTANT: Use int64Value, not intValue (which truncates!)
        var keyIds: [Int] = []
        if let rawKeys = params["keys"] as? [Any] {
            for rawKey in rawKeys {
                if let num = rawKey as? NSNumber {
                    // int64Value preserves the full value
                    keyIds.append(Int(num.int64Value))
                } else if let intVal = rawKey as? Int {
                    keyIds.append(intVal)
                } else if let int64Val = rawKey as? Int64 {
                    keyIds.append(Int(int64Val))
                }
            }
        }

        // Store capture configuration for this window
        capturedKeys[id] = Set(keyIds)
        captureAllKeys[id] = allKeys

        // Set up LOCAL key monitoring (for events within our app)
        if localKeyMonitor == nil {
            localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
                guard let self = self else { return event }

                // Convert macOS keyCode to Flutter logical key ID
                guard let flutterKeyId = InputService.keyCodeToFlutterKeyId[event.keyCode] else {
                    os_log("Unmapped keyCode=%{public}d type=%{public}@", log: Log.input, type: .debug, event.keyCode, event.type == .keyDown ? "keyDown" : "keyUp")
                    return event
                }

                // On keyUp: if the matching keyDown was passed through to FlutterViewController,
                // we MUST pass the keyUp through too — regardless of current capture state.
                // Otherwise HardwareKeyboard thinks the key is still pressed and asserts
                // on the next keyDown ("physical key is already pressed").
                let forcePassThrough = event.type == .keyUp
                    && self.passedThroughKeyCodes.contains(event.keyCode)

                if forcePassThrough {
                    self.passedThroughKeyCodes.remove(event.keyCode)
                }

                // Check if any window wants this key
                var shouldConsume = false

                for (capturedId, wantedKeys) in self.capturedKeys {
                    let wantsAllKeys = self.captureAllKeys[capturedId] ?? false
                    let wantsThisKey = wantsAllKeys || wantedKeys.contains(flutterKeyId)

                    if wantsThisKey {
                        let modifiers = self.modifierFlags(from: event)

                        // Notify main app via event sink
                        if event.type == .keyDown {
                            self.eventSink?("input", "keyDown", capturedId, [
                                "keyId": flutterKeyId,
                                "modifiers": modifiers
                            ])
                        } else {
                            self.eventSink?("input", "keyUp", capturedId, [
                                "keyId": flutterKeyId
                            ])
                        }

                        // Also forward directly to palette's Flutter engine via entryChannel
                        if let window = self.store.get(capturedId) {
                            DispatchQueue.main.async {
                                if event.type == .keyDown {
                                    window.entryChannel?.invokeMethod("keyDown", arguments: [
                                        "keyId": flutterKeyId,
                                        "modifiers": modifiers
                                    ])
                                } else {
                                    window.entryChannel?.invokeMethod("keyUp", arguments: [
                                        "keyId": flutterKeyId
                                    ])
                                }
                            }
                        }

                        shouldConsume = true
                    }
                }

                // Track keyDown pass-through so we can force matching keyUp through
                if event.type == .keyDown {
                    if shouldConsume {
                        self.passedThroughKeyCodes.remove(event.keyCode)
                    } else {
                        self.passedThroughKeyCodes.insert(event.keyCode)
                    }
                }

                // Never consume keyUp if the keyDown was passed through
                if forcePassThrough {
                    return event
                }

                return shouldConsume ? nil : event
            }
        }

        capturedWindows.insert(id)
        result(nil)
    }

    private func releaseKeyboard(windowId: String?, result: @escaping FlutterResult) {
        guard let id = windowId else {
            result(FlutterError(code: "MISSING_ID", message: "Window ID required", details: nil))
            return
        }

        capturedWindows.remove(id)
        capturedKeys.removeValue(forKey: id)
        captureAllKeys.removeValue(forKey: id)

        // Remove local monitor if no windows are capturing
        if capturedKeys.isEmpty, let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
            passedThroughKeyCodes.removeAll()
        }

        result(nil)
    }

    private func modifierFlags(from event: NSEvent) -> [Int] {
        var modifiers: [Int] = []
        let flags = event.modifierFlags

        if flags.contains(.shift) { modifiers.append(0x10000001) }
        if flags.contains(.control) { modifiers.append(0x10000002) }
        if flags.contains(.option) { modifiers.append(0x10000004) }
        if flags.contains(.command) { modifiers.append(0x10000008) }

        return modifiers
    }

    // MARK: - Pointer Capture

    /// Local monitor for mouse clicks (when app IS focused)
    private var localMouseMonitor: Any?


    private func capturePointer(windowId: String?, result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        os_log("capturePointer id=%{public}@", log: Log.input, type: .debug, id)

        // Track this window for click outside detection
        capturedWindows.insert(id)

        // Set up LOCAL click outside detection (when app IS focused)
        if localMouseMonitor == nil {
            localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self = self else { return event }

                let screenLocation = NSEvent.mouseLocation

                // Find if click is inside any visible palette window
                var clickedPaletteId: String? = nil
                for (id, window) in self.store.all() {
                    if window.panel.isVisible && window.panel.frame.contains(screenLocation) {
                        clickedPaletteId = id
                        break
                    }
                }

                // Fire clickOutside for each captured window (except the one clicked on)
                for capturedId in self.capturedWindows {
                    guard self.store.exists(capturedId) else { continue }
                    if capturedId == clickedPaletteId { continue }

                    self.eventSink?("input", "clickOutside", capturedId, [
                        "x": screenLocation.x,
                        "y": screenLocation.y,
                        "clickedPaletteId": clickedPaletteId as Any,
                    ])
                }

                // Pass the event through (don't consume mouse clicks)
                return event
            }
        }

        // Also set up GLOBAL monitor for when app is NOT focused
        if globalMouseMonitor == nil {
            globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self = self else { return }

                let screenLocation = NSEvent.mouseLocation

                // Find if click is inside any visible palette window
                var clickedPaletteId: String? = nil
                for (id, window) in self.store.all() {
                    if window.panel.isVisible && window.panel.frame.contains(screenLocation) {
                        clickedPaletteId = id
                        break
                    }
                }

                // Fire clickOutside for each captured window (except the one clicked on)
                for capturedId in self.capturedWindows {
                    guard self.store.exists(capturedId) else { continue }
                    if capturedId == clickedPaletteId { continue }

                    self.eventSink?("input", "clickOutside", capturedId, [
                        "x": screenLocation.x,
                        "y": screenLocation.y,
                        "clickedPaletteId": clickedPaletteId as Any,
                    ])
                }
            }
        }

        // Track mouse enter/exit
        window.panel.acceptsMouseMovedEvents = true

        // Set up tracking area for pointer enter/exit (works even when app is inactive)
        setupPointerTracking(for: id, window: window)

        result(nil)
    }

    /// Global monitor for mouse move (to track enter/exit even when app is inactive)
    private var globalMouseMoveMonitor: Any?

    /// Track which windows the mouse is currently inside
    private var mouseInsideWindows: Set<String> = []

    /// Set up pointer tracking for mouse enter/exit events.
    /// Uses global mouse move monitoring to work even when app is inactive.
    private func setupPointerTracking(for id: String, window: PaletteWindow) {
        os_log("setupPointerTracking id=%{public}@", log: Log.input, type: .debug, id)

        // Set up global mouse move monitor if not already set
        if globalMouseMoveMonitor == nil {
            os_log("creating global mouse move monitor", log: Log.input, type: .debug)
            globalMouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
                self?.checkMousePosition()
            }
        }

        // Also check on local mouse moves (when app IS focused)
        // Use a timer to periodically check mouse position
        startMousePositionTimer()
    }

    private var mousePositionTimer: Timer?

    private func startMousePositionTimer() {
        guard mousePositionTimer == nil else { return }
        os_log("starting mouse position timer", log: Log.input, type: .debug)
        mousePositionTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.checkMousePosition()
        }
    }

    private func stopMousePositionTimer() {
        mousePositionTimer?.invalidate()
        mousePositionTimer = nil
    }

    /// Check current mouse position against all tracked windows
    private func checkMousePosition() {
        let mouseLocation = NSEvent.mouseLocation

        for id in capturedWindows {
            guard let window = store.get(id) else { continue }
            let frame = window.panel.frame

            let isInside = frame.contains(mouseLocation)
            let wasInside = mouseInsideWindows.contains(id)

            if isInside && !wasInside {
                // Mouse entered
                os_log("mouse entered id=%{public}@", log: Log.input, type: .debug, id)
                mouseInsideWindows.insert(id)
                eventSink?("input", "pointerEnter", id, [:])
            } else if !isInside && wasInside {
                // Mouse exited
                os_log("mouse exited id=%{public}@", log: Log.input, type: .debug, id)
                mouseInsideWindows.remove(id)
                eventSink?("input", "pointerExit", id, [:])
            }
        }
    }

    private func releasePointer(windowId: String?, result: @escaping FlutterResult) {
        guard let id = windowId else {
            result(FlutterError(code: "MISSING_ID", message: "Window ID required", details: nil))
            return
        }

        capturedWindows.remove(id)
        mouseInsideWindows.remove(id)

        // Remove monitors if no windows are capturing
        if capturedWindows.isEmpty {
            if let monitor = localMouseMonitor {
                NSEvent.removeMonitor(monitor)
                localMouseMonitor = nil
            }
            if let monitor = globalMouseMonitor {
                NSEvent.removeMonitor(monitor)
                globalMouseMonitor = nil
            }
            if let monitor = globalMouseMoveMonitor {
                NSEvent.removeMonitor(monitor)
                globalMouseMoveMonitor = nil
            }
            stopMousePositionTimer()
        }

        result(nil)
    }

    // MARK: - Cursor

    private func setCursor(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, store.exists(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        guard let cursorKind = params["cursor"] as? String else {
            result(FlutterError(code: "INVALID_PARAMS", message: "cursor required", details: nil))
            return
        }

        DispatchQueue.main.async {
            let cursor = self.cursor(for: cursorKind)
            cursor.set()
            result(nil)
        }
    }

    private func resetCursor(windowId: String?, result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            NSCursor.arrow.set()
            result(nil)
        }
    }

    private func cursor(for kind: String) -> NSCursor {
        switch kind {
        case "arrow": return .arrow
        case "iBeam": return .iBeam
        case "crosshair": return .crosshair
        case "closedHand": return .closedHand
        case "openHand": return .openHand
        case "pointingHand": return .pointingHand
        case "resizeLeft": return .resizeLeft
        case "resizeRight": return .resizeRight
        case "resizeLeftRight": return .resizeLeftRight
        case "resizeUp": return .resizeUp
        case "resizeDown": return .resizeDown
        case "resizeUpDown": return .resizeUpDown
        case "disappearingItem": return .disappearingItem
        case "operationNotAllowed": return .operationNotAllowed
        case "dragLink": return .dragLink
        case "dragCopy": return .dragCopy
        case "contextualMenu": return .contextualMenu
        default: return .arrow
        }
    }

    // MARK: - Window Cleanup

    /// Clean up all input state for a destroyed window.
    func cleanupForWindow(_ id: String) {
        capturedWindows.remove(id)
        capturedKeys.removeValue(forKey: id)
        captureAllKeys.removeValue(forKey: id)
        mouseInsideWindows.remove(id)

        // Remove monitors if no windows remain
        if capturedWindows.isEmpty {
            if let monitor = localKeyMonitor {
                NSEvent.removeMonitor(monitor)
                localKeyMonitor = nil
                passedThroughKeyCodes.removeAll()
            }
            if let monitor = localMouseMonitor {
                NSEvent.removeMonitor(monitor)
                localMouseMonitor = nil
            }
            if let monitor = globalMouseMonitor {
                NSEvent.removeMonitor(monitor)
                globalMouseMonitor = nil
            }
            if let monitor = globalMouseMoveMonitor {
                NSEvent.removeMonitor(monitor)
                globalMouseMoveMonitor = nil
            }
            stopMousePositionTimer()
        }
    }

    // MARK: - Passthrough

    private func setPassthrough(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        let enabled = params["enabled"] as? Bool ?? true

        DispatchQueue.main.async {
            window.panel.ignoresMouseEvents = enabled
            result(nil)
        }
    }
}

